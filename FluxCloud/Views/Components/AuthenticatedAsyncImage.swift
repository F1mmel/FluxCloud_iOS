import SwiftUI

public struct AuthenticatedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false
    
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    public var body: some View {
        ZStack {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        guard !isLoading else { return }
        
        // Simple memory cache
        let cacheKey = NSString(string: url.absoluteString)
        if let cached = ImageCache.shared.get(forKey: cacheKey) {
            self.loadedImage = cached
            return
        }
        
        isLoading = true
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200, let uiImg = UIImage(data: data) {
                    ImageCache.shared.set(uiImg, forKey: cacheKey)
                    await MainActor.run {
                        self.loadedImage = uiImg
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run { self.isLoading = false }
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

public class ImageCache {
    public static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }
    
    public func get(forKey key: NSString) -> UIImage? {
        return cache.object(forKey: key)
    }
    
    public func set(_ image: UIImage, forKey key: NSString) {
        cache.setObject(image, forKey: key)
    }
}
