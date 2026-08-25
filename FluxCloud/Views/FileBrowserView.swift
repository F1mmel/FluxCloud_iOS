import SwiftUI

public struct FileBrowserView: View {
    @EnvironmentObject var authManager: AuthManager
    
    public var currentPath: String = ""
    public var folderTitle: String = "FluxCloud"
    
    @State private var items: [FileItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "all"
    @State private var selectedFileForDetail: FileItem? = nil
    @State private var showLogoutAlert: Bool = false
    
    private let categories = [
        ("all", "All"),
        ("folder", "Folders"),
        ("image", "Images"),
        ("video", "Videos"),
        ("document", "Documents"),
        ("code", "Code")
    ]
    
    public init(currentPath: String = "", folderTitle: String = "FluxCloud") {
        self.currentPath = currentPath
        self.folderTitle = folderTitle
    }
    
    public var filteredItems: [FileItem] {
        var result = items
        
        // Local search filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Category filter
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
                                                ? Color.blue
                                                : Color(UIColor.secondarySystemGroupedBackground)
                                        )
                                        .foregroundColor(selectedCategory == cat.0 ? .white : .primary)
                                        .cornerRadius(18)
                                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                
                // Content View
                if isLoading && items.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading files...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if let error = errorMessage, items.isEmpty {
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
                        Button("Try Again") {
                            Task { await loadFiles() }
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                } else if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(searchText.isEmpty ? "This folder is empty" : "No matching files found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            if item.isDirectory {
                                NavigationLink(destination: FileBrowserView(currentPath: item.relativePath, folderTitle: item.name)) {
                                    FileRowView(item: item, serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey)
                                }
                            } else {
                                Button(action: {
                                    selectedFileForDetail = item
                                }) {
                                    FileRowView(item: item, serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadFiles()
                    }
                }
            }
        }
        .navigationTitle(folderTitle)
        .navigationBarTitleDisplayMode(currentPath.isEmpty ? .large : .inline)
        .searchable(text: $searchText, prompt: "Search files...")
        .toolbar {
            if currentPath.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(header: Text(authManager.config.cleanedURLString)) {
                            Button(action: {
                                Task {
                                    await UpdateManager.shared.checkForUpdates(force: true)
                                }
                            }) {
                                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                            }
                            
                            Button(role: .destructive, action: {
                                showLogoutAlert = true
                            }) {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("Are you sure you want to sign out from this FluxCloud server?")
        }
        .sheet(item: $selectedFileForDetail) { item in
            FileDetailView(item: item)
                .environmentObject(authManager)
        }
        .task {
            await loadFiles()
        }
    }
    
    private func loadFiles() async {
        isLoading = true
        errorMessage = nil
        
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
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - File Row Component

private struct FileRowView: View {
    let item: FileItem
    let serverUrl: String
    let apiKey: String
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon or Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                if item.isImage, let thumbUrl = APIService.shared.getThumbnailURL(serverUrl: serverUrl, apiKey: apiKey, for: item) {
                    AuthenticatedAsyncImage(url: thumbUrl) { img in
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipped()
                            .cornerRadius(8)
                    } placeholder: {
                        Image(systemName: item.systemIconName)
                            .font(.system(size: 20))
                            .foregroundColor(item.iconColor)
                    }
                } else {
                    Image(systemName: item.systemIconName)
                        .font(.system(size: 20))
                        .foregroundColor(item.iconColor)
                }
            }
            
            // Name & Info
            VStack(alignment: .leading, spacing: 3) {
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
        }
        .padding(.vertical, 2)
    }
}
