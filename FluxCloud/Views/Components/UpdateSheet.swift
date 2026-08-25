import SwiftUI

public struct UpdateSheet: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showShareSheet: Bool = false
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 10)
                        
                        // Header Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.cyan.opacity(0.35), radius: 16, x: 0, y: 6)
                            
                            Image(systemName: "arrow.down.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.white)
                        }
                        
                        // Title & Subtitle
                        VStack(spacing: 8) {
                            Text("Neues Update verfügbar")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let release = updateManager.latestRelease {
                                Text("Veröffentlicht am \(release.formattedDate)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let size = release.ipaAsset?.formattedSize {
                                    Text("Dateigröße: \(size)")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.12))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        
                        // Release Notes Card (if present)
                        if let body = updateManager.latestRelease?.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Änderungen:")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                
                                Text(body)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                        
                        // Download Progress or Actions
                        VStack(spacing: 16) {
                            if updateManager.isDownloading {
                                VStack(spacing: 12) {
                                    ProgressView(value: updateManager.downloadProgress, total: 1.0)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                        .scaleEffect(x: 1, y: 2, anchor: .center)
                                        .cornerRadius(4)
                                    
                                    HStack {
                                        Text("Wird heruntergeladen...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(Int(updateManager.downloadProgress * 100))%")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Button(action: {
                                        updateManager.cancelDownload()
                                    }) {
                                        Text("Abbrechen")
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.top, 4)
                                }
                                .padding(18)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                                .padding(.horizontal)
                            } else if let _ = updateManager.downloadedIpaURL {
                                // Download completed
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                        Text("Download abgeschlossen!")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text("Öffne die .ipa-Datei mit AltStore, TrollStore, LiveContainer oder speichere sie in Dateien.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button(action: {
                                        showShareSheet = true
                                    }) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up.fill")
                                            Text("Installieren / In App öffnen")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color.green)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(18)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                                .padding(.horizontal)
                            } else {
                                // Not downloading yet
                                Button(action: {
                                    updateManager.startDownload()
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Jetzt aktualisieren")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    updateManager.markCurrentReleaseAsInstalled()
                                }) {
                                    Text("Später erinnern")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let error = updateManager.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                        }
                        
                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        updateManager.showUpdateSheet = false
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = updateManager.downloadedIpaURL {
                    ShareSheet(activityItems: [url])
                        .onDisappear {
                            updateManager.markCurrentReleaseAsInstalled()
                        }
                }
            }
        }
    }
}
