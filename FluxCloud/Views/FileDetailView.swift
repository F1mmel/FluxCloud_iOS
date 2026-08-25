import SwiftUI
import AVKit

public struct FileDetailView: View {
    public let item: FileItem
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var localFileURL: URL? = nil
    @State private var isDownloading: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var player: AVPlayer? = nil
    @State private var isPlayingAudio: Bool = false
    
    public var body: some View {
        // If this is an image, display the pure clean image preview directly
        if item.isImage {
            ImageViewerView(item: item)
                .environmentObject(authManager)
        } else {
            nonImageDetailView
        }
    }
    
    // MARK: - Non-Image File Detail View
    
    private var nonImageDetailView: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Video Player or Media Preview Card
                        if item.isVideo, let streamUrl = APIService.shared.getDirectDownloadURL(serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey, for: item) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black)
                                    .frame(height: 240)
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                                
                                VideoPlayer(player: player ?? AVPlayer(url: streamUrl))
                                    .frame(height: 240)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                            .onAppear {
                                if player == nil {
                                    player = AVPlayer(url: streamUrl)
                                }
                            }
                            .onDisappear {
                                player?.pause()
                            }
                        } else if item.isAudio, let streamUrl = APIService.shared.getDirectDownloadURL(serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey, for: item) {
                            // Audio Player Card
                            VStack(spacing: 16) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 48))
                                    .foregroundColor(.pink)
                                
                                Text(item.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    if isPlayingAudio {
                                        player?.pause()
                                        isPlayingAudio = false
                                    } else {
                                        if player == nil {
                                            player = AVPlayer(url: streamUrl)
                                        }
                                        player?.play()
                                        isPlayingAudio = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isPlayingAudio ? "pause.fill" : "play.fill")
                                            .font(.headline)
                                        Text(isPlayingAudio ? "Pause" : "Abspielen")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.pink)
                                    .cornerRadius(24)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            // File Icon Card
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    .frame(height: 180)
                                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                                
                                VStack(spacing: 12) {
                                    Image(systemName: item.systemIconName)
                                        .font(.system(size: 56))
                                        .foregroundColor(item.iconColor)
                                    
                                    Text(item.extensionName?.uppercased() ?? "DATEI")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(item.iconColor.opacity(0.15))
                                        .foregroundColor(item.iconColor)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Metadata Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Informationen")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Divider()
                            
                            DetailRow(title: "Dateiname", value: item.name)
                            DetailRow(title: "Pfad", value: item.relativePath)
                            DetailRow(title: "Größe", value: item.formattedSize)
                            if !item.formattedDate.isEmpty {
                                DetailRow(title: "Geändert am", value: item.formattedDate)
                            }
                            if let mime = item.mimeType {
                                DetailRow(title: "MIME-Type", value: mime)
                            }
                        }
                        .padding(18)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        // Error message if any
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                downloadAndShare()
                            }) {
                                HStack {
                                    if isDownloading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("Wird heruntergeladen...")
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Öffnen / Teilen")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(14)
                            }
                            .disabled(isDownloading)
                            
                            if let directUrl = APIService.shared.getDirectDownloadURL(serverUrl: authManager.config.serverUrl, apiKey: authManager.config.apiKey, for: item) {
                                Button(action: {
                                    UIPasteboard.general.url = directUrl
                                }) {
                                    HStack {
                                        Image(systemName: "link")
                                        Text("Download-Link kopieren")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer().frame(height: 20)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = localFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func downloadAndShare() {
        if let local = localFileURL {
            showShareSheet = true
            return
        }
        
        isDownloading = true
        errorMessage = nil
        
        Task {
            do {
                let url = try await APIService.shared.downloadFileToLocal(
                    serverUrl: authManager.config.serverUrl,
                    apiKey: authManager.config.apiKey,
                    item: item
                )
                await MainActor.run {
                    self.localFileURL = url
                    self.isDownloading = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Download fehlgeschlagen: \(error.localizedDescription)"
                    self.isDownloading = false
                }
            }
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
