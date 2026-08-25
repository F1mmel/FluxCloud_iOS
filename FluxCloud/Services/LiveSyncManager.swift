import Foundation
import Combine
import UIKit

extension Notification.Name {
    public static let fluxCloudFilesDidChange = Notification.Name("fluxCloudFilesDidChange")
}

public class LiveSyncManager: ObservableObject {
    public static let shared = LiveSyncManager()
    
    @Published public var isConnected: Bool = false
    @Published public var isConnecting: Bool = false
    @Published public var lastEventDescription: String? = nil
    @Published public var lastEventTime: Date? = nil
    
    private var streamTask: Task<Void, Never>? = nil
    private var pollTimer: Timer? = nil
    private var serverUrl: String = ""
    private var apiKey: String = ""
    private var shouldRun: Bool = false
    private var retryCount: Int = 0
    
    private init() {
        // Listen to app foreground notifications to immediately refresh
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAppDidBecomeActive() {
        if shouldRun {
            DebugLogger.shared.log("[LiveSync] App became active -> triggering refresh and reconnecting")
            NotificationCenter.default.post(name: .fluxCloudFilesDidChange, object: nil)
            if !isConnected && !isConnecting {
                connect()
            }
        }
    }
    
    // MARK: - Start Real-Time Live Sync
    
    public func start(serverUrl: String, apiKey: String) {
        guard !serverUrl.isEmpty else { return }
        self.serverUrl = ServerConfig.formatBaseURL(serverUrl)
        self.apiKey = apiKey
        self.shouldRun = true
        self.retryCount = 0
        
        DebugLogger.shared.log("[LiveSync] Starting real-time sync with \(self.serverUrl)...")
        connect()
        startPeriodicSync()
    }
    
    // MARK: - Stop Live Sync
    
    public func stop() {
        shouldRun = false
        streamTask?.cancel()
        streamTask = nil
        stopPeriodicSync()
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnecting = false
        }
        DebugLogger.shared.log("[LiveSync] Live sync stopped.")
    }
    
    // MARK: - Connect Loop with SSE
    
    private func connect() {
        streamTask?.cancel()
        
        streamTask = Task { [weak self] in
            guard let self = self, self.shouldRun else { return }
            
            await MainActor.run {
                self.isConnecting = true
            }
            
            var components = URLComponents(string: "\(self.serverUrl)/api/events")
            if !self.apiKey.isEmpty {
                components?.queryItems = [URLQueryItem(name: "key", value: self.apiKey)]
            }
            
            guard let url = components?.url else {
                await MainActor.run { self.isConnecting = false }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.timeoutInterval = 3600
            
            if !self.apiKey.isEmpty {
                if self.apiKey.hasPrefix("Basic ") {
                    request.setValue(self.apiKey, forHTTPHeaderField: "Authorization")
                } else {
                    request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                }
            }
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 3600
            config.timeoutIntervalForResource = 86400
            let session = URLSession(configuration: config)
            
            do {
                let (bytes, response) = try await session.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    DebugLogger.shared.log("[LiveSync] SSE status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.isConnected = true
                    self.isConnecting = false
                    self.retryCount = 0
                }
                DebugLogger.shared.log("[LiveSync] SSE stream connected!")
                
                for try await line in bytes.lines {
                    if !self.shouldRun { break }
                    
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("data:") {
                        let jsonString = trimmed.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
                        self.handleEventData(jsonString)
                    }
                }
            } catch {
                if !Task.isCancelled && self.shouldRun {
                    DebugLogger.shared.log("[LiveSync] Stream disconnected: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.isConnected = false
                self.isConnecting = false
            }
            
            // Reconnect logic with backoff
            if self.shouldRun && !Task.isCancelled {
                self.retryCount += 1
                let delay = min(Double(self.retryCount * 2), 10.0)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if self.shouldRun {
                    self.connect()
                }
            }
        }
    }
    
    // MARK: - Periodic Background Sync (Fail-Proof Heartbeat)
    
    private func startPeriodicSync() {
        DispatchQueue.main.async {
            self.pollTimer?.invalidate()
            // Periodic lightweight trigger every 5 seconds while active
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                guard let self = self, self.shouldRun else { return }
                NotificationCenter.default.post(name: .fluxCloudFilesDidChange, object: nil)
            }
        }
    }
    
    private func stopPeriodicSync() {
        DispatchQueue.main.async {
            self.pollTimer?.invalidate()
            self.pollTimer = nil
        }
    }
    
    // MARK: - Handle Incoming Event
    
    private func handleEventData(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        
        do {
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let type = (obj["type"] as? String) ?? "event"
                
                // Ignore raw connection ping
                if obj["connected"] != nil || type == "ping" {
                    return
                }
                
                DispatchQueue.main.async {
                    self.lastEventDescription = "Update: \(type)"
                    self.lastEventTime = Date()
                    DebugLogger.shared.log("[LiveSync] Server event received: \(type) -> Refreshing file browser")
                    
                    // Post notification to trigger instant UI refresh in file browser
                    NotificationCenter.default.post(
                        name: .fluxCloudFilesDidChange,
                        object: nil,
                        userInfo: obj
                    )
                }
            }
        } catch {}
    }
}
