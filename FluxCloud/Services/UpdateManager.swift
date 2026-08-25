import Foundation
import SwiftUI
import Combine

public class UpdateManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = UpdateManager()
    
    private let kFirstStartedKey = "fluxcloud_app_first_started_timestamp"
    private let kLastInstalledReleaseDateKey = "fluxcloud_last_installed_release_timestamp"
    private let kLastInstalledReleaseIdKey = "fluxcloud_last_installed_release_id"
    private let githubApiURL = "https://api.github.com/repos/F1mmel/FluxCloud_iOS/releases/latest"
    
    @Published public var isChecking: Bool = false
    @Published public var isUpdateAvailable: Bool = false
    @Published public var showUpdateSheet: Bool = false
    @Published public var latestRelease: GitHubRelease? = nil
    
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadedIpaURL: URL? = nil
    @Published public var errorMessage: String? = nil
    
    private var downloadTask: URLSessionDownloadTask? = nil
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    
    public override init() {
        super.init()
        initializeBaselineTimestamp()
    }
    
    /// Initializes and updates the baseline timestamp from the app binary
    private func initializeBaselineTimestamp() {
        var buildDate = Date()
        if let execURL = Bundle.main.executableURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: execURL.path),
           let modDate = attributes[.modificationDate] as? Date {
            buildDate = modDate
        }
        
        let savedInstalled = UserDefaults.standard.double(forKey: kLastInstalledReleaseDateKey)
        if buildDate.timeIntervalSince1970 > savedInstalled {
            UserDefaults.standard.set(buildDate.timeIntervalSince1970, forKey: kLastInstalledReleaseDateKey)
        }
        if UserDefaults.standard.object(forKey: kFirstStartedKey) == nil {
            UserDefaults.standard.set(buildDate.timeIntervalSince1970, forKey: kFirstStartedKey)
        }
    }
    
    public var referenceTimestamp: Date {
        var buildDate = Date()
        if let execURL = Bundle.main.executableURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: execURL.path),
           let modDate = attributes[.modificationDate] as? Date {
            buildDate = modDate
        }
        
        let ts = UserDefaults.standard.double(forKey: kLastInstalledReleaseDateKey)
        if ts > 0 {
            return Date(timeIntervalSince1970: max(ts, buildDate.timeIntervalSince1970))
        }
        return buildDate
    }
    
    // MARK: - Check for Updates
    
    @MainActor
    public func checkForUpdates(force: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil
        
        DebugLogger.shared.log("Checking GitHub for new releases...")
        
        guard let url = URL(string: githubApiURL) else {
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("FluxCloud-iOS-AutoUpdater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        do {
            var release: GitHubRelease? = nil
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
            } else {
                // Fallback to /releases array endpoint
                if let fallbackURL = URL(string: "https://api.github.com/repos/F1mmel/FluxCloud_iOS/releases") {
                    var fallbackReq = URLRequest(url: fallbackURL)
                    fallbackReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                    fallbackReq.setValue("FluxCloud-iOS-AutoUpdater", forHTTPHeaderField: "User-Agent")
                    let (fData, fResponse) = try await URLSession.shared.data(for: fallbackReq)
                    if let fHttp = fResponse as? HTTPURLResponse, fHttp.statusCode == 200 {
                        let releases = (try? JSONDecoder().decode([GitHubRelease].self, from: fData)) ?? []
                        release = releases.first
                    }
                }
            }
            
            guard let latest = release, let releaseDate = latest.effectiveDate else {
                DebugLogger.shared.log("No GitHub release found.")
                isChecking = false
                return
            }
            
            let localDate = referenceTimestamp
            let lastInstalledId = UserDefaults.standard.integer(forKey: kLastInstalledReleaseIdKey)
            
            DebugLogger.shared.log("Latest release date: \(latest.formattedDate) | App baseline: \(DateFormatter.localizedString(from: localDate, dateStyle: .medium, timeStyle: .short))")
            
            // If already marked as installed ID and not force, skip
            if !force && lastInstalledId > 0 && lastInstalledId == latest.id {
                DebugLogger.shared.log("App is already on the latest release ID (\(latest.id)).")
                self.isUpdateAvailable = false
                isChecking = false
                return
            }
            
            // Compare release timestamp with local app build timestamp (+60s tolerance)
            if releaseDate.timeIntervalSince1970 > (localDate.timeIntervalSince1970 + 60.0) || force {
                DebugLogger.shared.log("New release available! Published on: \(latest.formattedDate)")
                self.latestRelease = latest
                self.isUpdateAvailable = true
                self.showUpdateSheet = true
            } else {
                DebugLogger.shared.log("App is up to date.")
                self.isUpdateAvailable = false
            }
            isChecking = false
        } catch {
            DebugLogger.shared.log("Error checking for updates: \(error.localizedDescription)")
            isChecking = false
        }
    }
    
    // MARK: - Download IPA
    
    @MainActor
    public func startDownload() {
        guard let release = latestRelease, let asset = release.ipaAsset, let downloadURL = URL(string: asset.browserDownloadUrl) else {
            errorMessage = "Keine .ipa Datei im neuesten Release gefunden."
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        downloadedIpaURL = nil
        
        DebugLogger.shared.log("Downloading FluxCloud.ipa (\(asset.formattedSize))...")
        
        var request = URLRequest(url: downloadURL)
        request.setValue("FluxCloud-iOS-AutoUpdater", forHTTPHeaderField: "User-Agent")
        
        downloadTask = urlSession.downloadTask(with: request)
        downloadTask?.resume()
    }
    
    @MainActor
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
    }
    
    public func markCurrentReleaseAsInstalled() {
        if let release = latestRelease {
            UserDefaults.standard.set(release.id, forKey: kLastInstalledReleaseIdKey)
            if let releaseDate = release.effectiveDate {
                UserDefaults.standard.set(releaseDate.timeIntervalSince1970, forKey: kLastInstalledReleaseDateKey)
            }
            DispatchQueue.main.async {
                self.isUpdateAvailable = false
                self.showUpdateSheet = false
            }
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadProgress = progress
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("FluxCloudUpdates", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: tempDir.path) {
                try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            }
            
            let destURL = tempDir.appendingPathComponent("FluxCloud.ipa")
            if fileManager.fileExists(atPath: destURL.path) {
                try? fileManager.removeItem(at: destURL)
            }
            
            try fileManager.moveItem(at: location, to: destURL)
            
            DispatchQueue.main.async {
                self.downloadedIpaURL = destURL
                self.isDownloading = false
                self.downloadProgress = 1.0
                DebugLogger.shared.log("FluxCloud.ipa downloaded successfully!")
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.errorMessage = "Fehler beim Speichern der Datei: \(error.localizedDescription)"
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
