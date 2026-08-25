import SwiftUI
import Photos

public struct ImageViewerView: View {
    public let item: FileItem
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    // Zoom & Pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Actions & UI state
    @State private var downloadedImage: UIImage? = nil
    @State private var isDownloading: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var localShareURL: URL? = nil
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    @State private var errorMessage: String? = nil
    
    public init(item: FileItem) {
        self.item = item
    }
    
    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Image Content with Pinch & Pan
            GeometryReader { proxy in
                ZStack {
                    if let image = downloadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newScale = scale * delta
                                        scale = min(max(newScale, 0.8), 6.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        if scale > 1.0 {
                                            lastOffset = offset
                                        } else {
                                            withAnimation(.spring()) {
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
                    } else if isDownloading {
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Bild wird geladen...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Erneut versuchen") {
                                Task { await loadImage() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            
            // Top Action Bar
            VStack {
                HStack(spacing: 16) {
                    // Dismiss Button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Save to Photos Button
                    if downloadedImage != nil {
                        Button(action: {
                            saveImageToPhotos()
                        }) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    
                    // Share Button
                    Button(action: {
                        shareImage()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Spacer()
            }
            
            // Success Toast
            if showToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(msg)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.15, green: 0.17, blue: 0.22).opacity(0.95))
                    .cornerRadius(20)
                    .shadow(radius: 8)
                    .padding(.bottom, 36)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = downloadedImage {
                ShareSheet(activityItems: [img])
            } else if let url = localShareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .task {
            await loadImage()
        }
    }
    
    // MARK: - Load High-Res Image
    
    private func loadImage() async {
        isDownloading = true
        errorMessage = nil
        
        guard let url = APIService.shared.getDirectDownloadURL(
            serverUrl: authManager.config.serverUrl,
            apiKey: authManager.config.apiKey,
            for: item
        ) else {
            errorMessage = "Ungültige Bild-URL"
            isDownloading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(authManager.config.apiKey, forHTTPHeaderField: "x-api-key")
        if !authManager.config.apiKey.isEmpty {
            if authManager.config.apiKey.hasPrefix("Basic ") {
                request.setValue(authManager.config.apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(authManager.config.apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.downloadedImage = uiImage
                    self.isDownloading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Bild konnte nicht geladen werden"
                    self.isDownloading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isDownloading = false
            }
        }
    }
    
    // MARK: - Save to Photos
    
    private func saveImageToPhotos() {
        guard let image = downloadedImage else { return }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    triggerToast("In Fotos gesichert ✓")
                } else {
                    triggerToast("Zugriff auf Fotos verweigert")
                }
            }
        }
    }
    
    private func shareImage() {
        if downloadedImage != nil {
            showShareSheet = true
        } else {
            Task {
                do {
                    let localURL = try await APIService.shared.downloadFileToLocal(
                        serverUrl: authManager.config.serverUrl,
                        apiKey: authManager.config.apiKey,
                        item: item
                    )
                    await MainActor.run {
                        self.localShareURL = localURL
                        self.showShareSheet = true
                    }
                } catch {
                    triggerToast("Download fehlgeschlagen")
                }
            }
        }
    }
    
    private func triggerToast(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }
}
