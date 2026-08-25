import SwiftUI
import Photos
import AVKit

public struct TransparentBackgroundView: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
            view.superview?.backgroundColor = .clear
            if let parent = view.parentViewController {
                parent.view.backgroundColor = .clear
            }
        }
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
}

private extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

public struct ImageViewerView: View {
    public let item: FileItem
    public var onDismiss: (() -> Void)? = nil
    
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    // Zoom & Pan state (for Images)
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Swipe Down to Dismiss state
    @State private var dragDismissOffset: CGFloat = 0.0
    @State private var isDraggingToDismiss: Bool = false
    
    // Media & Player state
    @State private var downloadedImage: UIImage? = nil
    @State private var player: AVPlayer? = nil
    @State private var isDownloading: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var localShareURL: URL? = nil
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    @State private var errorMessage: String? = nil
    
    public init(item: FileItem, onDismiss: (() -> Void)? = nil) {
        self.item = item
        self.onDismiss = onDismiss
    }
    
    // Background opacity fades to 0 as user drags down, revealing the underlying files
    private var backgroundOpacity: Double {
        if isDraggingToDismiss {
            let progress = Double(dragDismissOffset / 250.0)
            return max(0.0, 1.0 - progress)
        }
        return 1.0
    }
    
    public var body: some View {
        ZStack {
            // Transparent Root Hosting Layer
            TransparentBackgroundView()
                .ignoresSafeArea()
            
            // Dynamic Dimming Layer (fades on drag)
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
            
            // Media Content (Image or Video) spanning entire screen
            GeometryReader { proxy in
                ZStack {
                    if item.isVideo {
                        videoContentView(proxy: proxy)
                    } else {
                        imageContentView(proxy: proxy)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()
            
            // Top Floating Action Bar
            VStack {
                HStack(spacing: 16) {
                    // Dismiss Button
                    Button(action: {
                        dismissViewer()
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
                    Button(action: {
                        saveMediaToPhotos()
                    }) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    // Share Button
                    Button(action: {
                        shareMedia()
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
                .padding(.top, 54) // Position cleanly below status bar
                .opacity(isDraggingToDismiss ? max(0, 1.0 - (dragDismissOffset / 100.0)) : 1.0)
                
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            
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
        .background(TransparentBackgroundView())
        .sheet(isPresented: $showShareSheet) {
            if let img = downloadedImage {
                ShareSheet(activityItems: [img])
            } else if let url = localShareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .task {
            if item.isVideo {
                setupAndPlayVideo()
            } else {
                await loadImage()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func dismissViewer() {
        player?.pause()
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Video Content View
    
    @ViewBuilder
    private func videoContentView(proxy: GeometryProxy) -> some View {
        ZStack {
            // Thumbnail preview while video is buffering
            if let thumbUrl = APIService.shared.getThumbnailURL(serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey, for: item) {
                AuthenticatedAsyncImage(url: thumbUrl) { img in
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            
            // Autoplay Video Player
            if let activePlayer = player {
                VideoPlayer(player: activePlayer)
                    .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.3)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Video wird geladen...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .scaleEffect(isDraggingToDismiss ? max(0.8, 1.0 - (dragDismissOffset / 1200.0)) : 1.0)
        .offset(y: dragDismissOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        isDraggingToDismiss = true
                        dragDismissOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if dragDismissOffset > 90 || value.predictedEndTranslation.height > 200 {
                        player?.pause()
                        withAnimation(.easeOut(duration: 0.18)) {
                            dragDismissOffset = proxy.size.height
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            dismissViewer()
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            dragDismissOffset = 0
                            isDraggingToDismiss = false
                        }
                    }
                }
        )
    }
    
    // MARK: - Image Content View
    
    @ViewBuilder
    private func imageContentView(proxy: GeometryProxy) -> some View {
        ZStack {
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(isDraggingToDismiss ? max(0.8, 1.0 - (dragDismissOffset / 1200.0)) : scale)
                    .offset(
                        x: scale > 1.05 ? offset.width : 0,
                        y: scale > 1.05 ? offset.height : dragDismissOffset
                    )
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
                                if scale > 1.05 {
                                    // Panning zoomed image
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                } else {
                                    // Swipe down to dismiss gesture
                                    if value.translation.height > 0 {
                                        isDraggingToDismiss = true
                                        dragDismissOffset = value.translation.height
                                    }
                                }
                            }
                            .onEnded { value in
                                if scale > 1.05 {
                                    lastOffset = offset
                                } else {
                                    // Threshold for dismissing
                                    if dragDismissOffset > 90 || value.predictedEndTranslation.height > 200 {
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            dragDismissOffset = proxy.size.height
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                            dismissViewer()
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            dragDismissOffset = 0
                                            isDraggingToDismiss = false
                                        }
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
                // Show thumbnail placeholder while high-res loads
                ZStack {
                    if let thumbUrl = APIService.shared.getThumbnailURL(serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey, for: item) {
                        AuthenticatedAsyncImage(url: thumbUrl) { img in
                            img
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
                                .blur(radius: 2)
                        } placeholder: {
                            EmptyView()
                        }
                    }
                    
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Bild wird geladen...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
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
    }
    
    // MARK: - Video Setup & Autoplay
    
    private func setupAndPlayVideo() {
        guard let streamUrl = APIService.shared.getDirectDownloadURL(
            serverUrl: authManager.config.serverUrl,
            apiKey: authManager.config.apiKey,
            for: item
        ) else {
            errorMessage = "Ungültige Video-URL"
            return
        }
        
        let p = AVPlayer(url: streamUrl)
        self.player = p
        p.play()
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
    
    // MARK: - Save Media to Photos
    
    private func saveMediaToPhotos() {
        if item.isVideo {
            Task {
                do {
                    let localURL = try await APIService.shared.downloadFileToLocal(
                        serverUrl: authManager.config.serverUrl,
                        apiKey: authManager.config.apiKey,
                        item: item
                    )
                    
                    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                        DispatchQueue.main.async {
                            if status == .authorized || status == .limited {
                                UISaveVideoAtPathToSavedPhotosAlbum(localURL.path, nil, nil, nil)
                                triggerToast("Video in Fotos gesichert ✓")
                            } else {
                                triggerToast("Zugriff auf Fotos verweigert")
                            }
                        }
                    }
                } catch {
                    triggerToast("Download fehlgeschlagen")
                }
            }
        } else {
            guard let image = downloadedImage else {
                triggerToast("Bild noch nicht geladen")
                return
            }
            
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
    }
    
    private func shareMedia() {
        if !item.isVideo && downloadedImage != nil {
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
