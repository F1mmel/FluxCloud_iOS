import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

public struct FileBrowserView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var liveSyncManager = LiveSyncManager.shared
    
    public var currentPath: String = ""
    public var folderTitle: String = "FluxCloud"
    
    // Data State
    @State private var items: [FileItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "all"
    @State private var isGridView: Bool = false
    
    // Detail / Preview Sheet State
    @State private var selectedFileForDetail: FileItem? = nil
    @State private var showLogoutAlert: Bool = false
    
    // Upload & Picker State
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showDocumentPicker: Bool = false
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0.0
    @State private var uploadStatusText: String = ""
    
    // Folder Creation State
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    
    // Rename State
    @State private var itemToRename: FileItem? = nil
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    
    // Delete State
    @State private var itemToDelete: FileItem? = nil
    @State private var showDeleteAlert: Bool = false
    
    // Toast State
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    
    private let categories = [
        ("all", "Alle"),
        ("folder", "Ordner"),
        ("image", "Bilder"),
        ("video", "Videos"),
        ("document", "Dokumente"),
        ("code", "Code")
    ]
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 12)
    ]
    
    public init(currentPath: String = "", folderTitle: String = "FluxCloud") {
        self.currentPath = currentPath
        self.folderTitle = folderTitle
    }
    
    public var filteredItems: [FileItem] {
        var result = items
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        if selectedCategory != "all" {
            switch selectedCategory {
            case "folder":
                result = result.filter { $0.isDirectory }
            case "image":
                result = result.filter { $0.isImage }
            case "video":
                result = result.filter { $0.isVideo }
            case "document":
                result = result.filter { $0.isDocument }
            case "code":
                result = result.filter { $0.isCode }
            default:
                break
            }
        }
        
        return result
    }
    
    public var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Category Filter Pills
                if !items.isEmpty {
                    categoryFilterScrollView
                }
                
                // Main Content View (Always Scrollable, Top-Aligned with Pull-to-Refresh)
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if isLoading && items.isEmpty {
                                loadingStateView(height: geometry.size.height)
                            } else if let error = errorMessage, items.isEmpty {
                                errorStateView(error: error, height: geometry.size.height)
                            } else if filteredItems.isEmpty {
                                emptyStateView(height: geometry.size.height)
                            } else {
                                if isGridView {
                                    gridViewLayout
                                } else {
                                    listViewLayout
                                }
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .top)
                    }
                    .refreshable {
                        await loadFiles(isSilent: false)
                    }
                }
            }
            
            // Upload Progress Banner Overlay
            if isUploading {
                VStack {
                    Spacer()
                    uploadProgressHUD
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Toast Notification Overlay
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
                    .padding(.bottom, isUploading ? 90 : 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(folderTitle)
        .navigationBarTitleDisplayMode(currentPath.isEmpty ? .large : .inline)
        .searchable(text: $searchText, prompt: "Dateien durchsuchen...")
        .toolbar {
            // Live Status Indicator in Leading Toolbar
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(liveSyncManager.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    if !liveSyncManager.isConnected && liveSyncManager.isConnecting {
                        Text("Live...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Trailing Actions (Grid Toggle, Upload '+', Profile Menu)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // View Mode Toggle Button
                Button(action: {
                    withAnimation { isGridView.toggle() }
                }) {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                
                // Add / Upload Menu (+)
                Menu {
                    // Photo / Video Picker Button
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 20,
                        matching: .any(of: [.images, .videos, .livePhotos, .cinematicVideos])
                    ) {
                        Label("Fotos & Videos hochladen", systemImage: "photo.on.rectangle.angled")
                    }
                    
                    // Document / File Picker Button
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Label("Dateien hochladen", systemImage: "doc.badge.plus")
                    }
                    
                    Divider()
                    
                    // New Folder Button
                    Button(action: {
                        newFolderName = ""
                        showNewFolderAlert = true
                    }) {
                        Label("Neuer Ordner", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                // Profile & App Menu
                if currentPath.isEmpty {
                    Menu {
                        Section(header: Text(authManager.config.cleanedURLString)) {
                            if !authManager.config.username.isEmpty {
                                Label("Benutzer: \(authManager.config.username)", systemImage: "person.circle")
                            }
                            
                            Button(action: {
                                Task {
                                    await UpdateManager.shared.checkForUpdates(force: true)
                                }
                            }) {
                                Label("Nach Updates suchen", systemImage: "arrow.triangle.2.circlepath")
                            }
                            
                            Button(role: .destructive, action: {
                                showLogoutAlert = true
                            }) {
                                Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20))
                    }
                }
            }
        }
        // File Document Importer
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleDocumentPickerResult(result)
        }
        // PhotosPicker Change Handler
        .onChange(of: selectedPhotoItems) { newItems in
            guard !newItems.isEmpty else { return }
            handlePhotoPickerUpload(newItems)
        }
        // New Folder Dialog Alert
        .alert("Neuer Ordner", isPresented: $showNewFolderAlert) {
            TextField("Ordnername", text: $newFolderName)
            Button("Erstellen") {
                handleCreateFolder()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Gib einen Namen für den neuen Ordner ein.")
        }
        // Rename Dialog Alert
        .alert("Umbenennen", isPresented: $showRenameAlert) {
            TextField("Neuer Name", text: $renameText)
            Button("Speichern") {
                handleRenameSubmit()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Gib einen neuen Namen für '\(itemToRename?.name ?? "")' ein.")
        }
        // Delete Confirmation Alert
        .alert("Löschen bestätigen", isPresented: $showDeleteAlert) {
            Button("Löschen", role: .destructive) {
                handleDeleteSubmit()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Möchtest du '\(itemToDelete?.name ?? "dieses Element")' wirklich löschen?")
        }
        // Sign Out Alert
        .alert("Abmelden", isPresented: $showLogoutAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Abmelden", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("Möchtest du dich wirklich von diesem FluxCloud-Server abmelden?")
        }
        // Full Preview Sheet (FileDetailView / ImageViewerView)
        .sheet(item: $selectedFileForDetail) { item in
            FileDetailView(item: item)
                .environmentObject(authManager)
        }
        // Real-Time Live Sync Notification Listener
        .onReceive(NotificationCenter.default.publisher(for: .fluxCloudFilesDidChange)) { _ in
            Task {
                await loadFiles(isSilent: true)
            }
        }
        .task {
            await loadFiles(isSilent: false)
        }
    }
    
    // MARK: - Category Filter ScrollView (Accent Color Highlight)
    
    private var categoryFilterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.0) { cat in
                    Button(action: {
                        withAnimation {
                            selectedCategory = cat.0
                        }
                    }) {
                        Text(cat.1)
                            .font(.subheadline)
                            .fontWeight(selectedCategory == cat.0 ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedCategory == cat.0
                                    ? Color.blue.opacity(0.18)
                                    : Color(UIColor.secondarySystemGroupedBackground)
                            )
                            .foregroundColor(selectedCategory == cat.0 ? Color.blue : .primary)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(selectedCategory == cat.0 ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - List View Layout
    
    private var listViewLayout: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredItems) { item in
                if item.isDirectory {
                    NavigationLink(destination: FileBrowserView(currentPath: item.relativePath, folderTitle: item.name)) {
                        FileRowView(item: item, serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                } else {
                    // Full row tap area including whitespace on the right
                    Button(action: {
                        selectedFileForDetail = item
                    }) {
                        FileRowView(item: item, serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Grid View Layout
    
    private var gridViewLayout: some View {
        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(filteredItems) { item in
                if item.isDirectory {
                    NavigationLink(destination: FileBrowserView(currentPath: item.relativePath, folderTitle: item.name)) {
                        FileGridItemView(item: item, serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                } else {
                    Button(action: {
                        selectedFileForDetail = item
                    }) {
                        FileGridItemView(item: item, serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func itemContextMenu(for item: FileItem) -> some View {
        Button(action: {
            selectedFileForDetail = item
        }) {
            Label(item.isDirectory ? "Öffnen" : "Vorschau", systemImage: item.isDirectory ? "folder" : "eye")
        }
        
        if let directUrl = APIService.shared.getDirectDownloadURL(serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey, for: item) {
            Button(action: {
                UIPasteboard.general.url = directUrl
                showToast("Download-Link kopiert ✓")
            }) {
                Label("Link kopieren", systemImage: "link")
            }
        }
        
        Button(action: {
            itemToRename = item
            renameText = item.name
            showRenameAlert = true
        }) {
            Label("Umbenennen", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            itemToDelete = item
            showDeleteAlert = true
        }) {
            Label("Löschen", systemImage: "trash")
        }
    }
    
    // MARK: - Empty & Loading States
    
    private func loadingStateView(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Dateien werden geladen...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(height - 100, 200))
    }
    
    private func errorStateView(error: String, height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Erneut versuchen") {
                Task { await loadFiles(isSilent: false) }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(height - 100, 200))
    }
    
    private func emptyStateView(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.4))
            
            Text(searchText.isEmpty ? "Dieser Ordner ist leer" : "Keine passenden Dateien gefunden")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Text("Ziehe nach unten zum Aktualisieren oder tippe auf +, um Dateien hochzuladen.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(height - 100, 200))
    }
    
    // MARK: - Upload Progress HUD
    
    private var uploadProgressHUD: some View {
        HStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.9)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(uploadStatusText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                ProgressView(value: uploadProgress, total: 1.0)
                    .tint(.cyan)
                    .background(Color.white.opacity(0.2))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.95))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Actions & Handlers
    
    private func loadFiles(isSilent: Bool = false) async {
        if !isSilent {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let files = try await APIService.shared.fetchFiles(
                serverUrl: authManager.config.serverUrl,
                apiKey: authManager.config.apiKey,
                path: currentPath
            )
            await MainActor.run {
                self.items = files
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                if !isSilent {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Photo & Video Upload Handler
    
    private func handlePhotoPickerUpload(_ pickerItems: [PhotosPickerItem]) {
        isUploading = true
        uploadProgress = 0.0
        uploadStatusText = "\(pickerItems.count) Element(e) werden geladen..."
        
        Task {
            var successCount = 0
            for (index, item) in pickerItems.enumerated() {
                await MainActor.run {
                    self.uploadStatusText = "Verarbeite (\(index + 1)/\(pickerItems.count))..."
                    self.uploadProgress = Double(index) / Double(pickerItems.count)
                }
                
                if let (data, filename, mime) = await loadMediaItemData(from: item, index: index + 1) {
                    await MainActor.run {
                        self.uploadStatusText = "Lade hoch (\(index + 1)/\(pickerItems.count)): \(filename)"
                    }
                    
                    do {
                        let success = try await APIService.shared.uploadFile(
                            serverUrl: authManager.config.serverUrl,
                            apiKey: authManager.config.apiKey,
                            path: currentPath,
                            filename: filename,
                            data: data,
                            mimeType: mime
                        )
                        if success { successCount += 1 }
                    } catch {
                        DebugLogger.shared.log("Upload failed for \(filename): \(error.localizedDescription)")
                    }
                } else {
                    DebugLogger.shared.log("Failed to extract data from PhotosPickerItem #\(index + 1)")
                }
            }
            
            await MainActor.run {
                self.selectedPhotoItems = []
                self.isUploading = false
                self.uploadProgress = 1.0
                if successCount > 0 {
                    self.showToast("\(successCount) Foto(s)/Video(s) erfolgreich hochgeladen ✓")
                } else {
                    self.showToast("Upload fehlgeschlagen")
                }
            }
            
            await loadFiles(isSilent: true)
        }
    }
    
    /// Loads raw binary data, filename, and MIME type from any PhotosPickerItem (Photos, LivePhotos, Videos)
    private func loadMediaItemData(from item: PhotosPickerItem, index: Int) async -> (Data, String, String)? {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // 1. Try URL file export (works best for videos and full-res raw media)
        if let fileURL = try? await item.loadTransferable(type: URL.self) {
            if let data = try? Data(contentsOf: fileURL) {
                let name = fileURL.lastPathComponent
                let ext = fileURL.pathExtension.lowercased()
                let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
                return (data, name, mime)
            }
        }
        
        // 2. Try raw Data loading
        if let rawData = try? await item.loadTransferable(type: Data.self) {
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            let filename = "MEDIA_\(timestamp)_\(index).\(ext)"
            return (rawData, filename, mime)
        }
        
        // 3. Try Image loading fallback
        if let image = try? await item.loadTransferable(type: Image.self) {
            // Render SwiftUI Image to UIImage
            let renderer = ImageRenderer(content: image)
            if let uiImage = renderer.uiImage, let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
                return (jpegData, "IMG_\(timestamp)_\(index).jpg", "image/jpeg")
            }
        }
        
        return nil
    }
    
    private func handleDocumentPickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isUploading = true
            uploadProgress = 0.0
            uploadStatusText = "\(urls.count) Datei(en) werden hochgeladen..."
            
            Task {
                var successCount = 0
                for (index, fileUrl) in urls.enumerated() {
                    let shouldStopAccessing = fileUrl.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStopAccessing { fileUrl.stopAccessingSecurityScopedResource() }
                    }
                    
                    do {
                        let data = try Data(contentsOf: fileUrl)
                        let filename = fileUrl.lastPathComponent
                        let mime = UTType(filenameExtension: fileUrl.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                        
                        await MainActor.run {
                            self.uploadStatusText = "Lade hoch (\(index + 1)/\(urls.count)): \(filename)"
                            self.uploadProgress = Double(index) / Double(urls.count)
                        }
                        
                        let success = try await APIService.shared.uploadFile(
                            serverUrl: authManager.config.serverUrl,
                            apiKey: authManager.config.apiKey,
                            path: currentPath,
                            filename: filename,
                            data: data,
                            mimeType: mime
                        )
                        if success { successCount += 1 }
                    } catch {
                        DebugLogger.shared.log("Error uploading document: \(error.localizedDescription)")
                    }
                }
                
                await MainActor.run {
                    self.isUploading = false
                    self.uploadProgress = 1.0
                    if successCount > 0 {
                        self.showToast("\(successCount) Datei(en) erfolgreich hochgeladen ✓")
                    }
                }
                
                await loadFiles(isSilent: true)
            }
        case .failure(let error):
            showToast("Fehler bei Dateiauswahl: \(error.localizedDescription)")
        }
    }
    
    private func handleCreateFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        Task {
            do {
                _ = try await APIService.shared.createFolder(
                    serverUrl: authManager.config.serverUrl,
                    apiKey: authManager.config.apiKey,
                    path: currentPath,
                    name: name
                )
                showToast("Ordner '\(name)' erstellt ✓")
                await loadFiles(isSilent: true)
            } catch {
                showToast("Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleRenameSubmit() {
        guard let item = itemToRename else { return }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty && newName != item.name else { return }
        
        Task {
            do {
                _ = try await APIService.shared.renameItem(
                    serverUrl: authManager.config.serverUrl,
                    apiKey: authManager.config.apiKey,
                    path: item.relativePath,
                    newName: newName
                )
                showToast("Umbenannt in '\(newName)' ✓")
                await loadFiles(isSilent: true)
            } catch {
                showToast("Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleDeleteSubmit() {
        guard let item = itemToDelete else { return }
        
        Task {
            do {
                _ = try await APIService.shared.deleteItems(
                    serverUrl: authManager.config.serverUrl,
                    apiKey: authManager.config.apiKey,
                    paths: [item.relativePath],
                    permanent: false
                )
                showToast("'\(item.name)' gelöscht ✓")
                await loadFiles(isSilent: true)
            } catch {
                showToast("Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }
}

// MARK: - File Row Component (Full Row Tapable)

private struct FileRowView: View {
    let item: FileItem
    let serverUrl: String
    let apiKey: String
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon or Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                if (item.isImage || item.isVideo), let thumbUrl = APIService.shared.getThumbnailURL(serverUrl: serverUrl, apiKey: apiKey, for: item) {
                    AuthenticatedAsyncImage(url: thumbUrl) { img in
                        ZStack {
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipped()
                                .cornerRadius(10)
                            
                            if item.isVideo {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 20, height: 20)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                            }
                        }
                    } placeholder: {
                        Image(systemName: item.systemIconName)
                            .font(.system(size: 22))
                            .foregroundColor(item.iconColor)
                    }
                } else {
                    Image(systemName: item.systemIconName)
                        .font(.system(size: 22))
                        .foregroundColor(item.iconColor)
                }
            }
            
            // Name & Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(item.formattedSize)
                    if !item.formattedDate.isEmpty {
                        Text("•")
                        Text(item.formattedDate)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .contentShape(Rectangle())
    }
}

// MARK: - File Grid Item Component

private struct FileGridItemView: View {
    let item: FileItem
    let serverUrl: String
    let apiKey: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.iconColor.opacity(0.12))
                    .aspectRatio(1, contentMode: .fit)
                
                if (item.isImage || item.isVideo), let thumbUrl = APIService.shared.getThumbnailURL(serverUrl: serverUrl, apiKey: apiKey, for: item) {
                    AuthenticatedAsyncImage(url: thumbUrl) { img in
                        ZStack {
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .clipped()
                                .cornerRadius(12)
                            
                            if item.isVideo {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.55))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    } placeholder: {
                        Image(systemName: item.systemIconName)
                            .font(.system(size: 32))
                            .foregroundColor(item.iconColor)
                    }
                } else {
                    Image(systemName: item.systemIconName)
                        .font(.system(size: 36))
                        .foregroundColor(item.iconColor)
                }
            }
            .frame(maxWidth: .infinity)
            
            Text(item.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .contentShape(Rectangle())
    }
}
