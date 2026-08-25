import Foundation
import Combine

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
    private var serverUrl: String = ""
    private var apiKey: String = ""
    private var shouldRun: Bool = false
    private var retryCount: Int = 0
    
    private init() {}
    
    // MARK: - Start Real-Time Live Sync
    
    public func start(serverUrl: String, apiKey: String) {
        guard !serverUrl.isEmpty else { return }
        self.serverUrl = ServerConfig.formatBaseURL(serverUrl)
        self.apiKey = apiKey
        self.shouldRun = true
        self.retryCount = 0
        
        DebugLogger.shared.log("[LiveSync] Starting real-time sync with \(self.serverUrl)...")
        connect()
    }
    
    // MARK: - Stop Live Sync
    
    public func stop() {
        shouldRun = false
        streamTask?.cancel()
        streamTask = nil
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
            if !self.apiKey.isEmpty && !self.apiKey.hasPrefix("Basic ") {
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
            request.timeoutInterval = 300 // long-lived stream
            
            if !self.apiKey.isEmpty {
                if self.apiKey.hasPrefix("Basic ") {
                    request.setValue(self.apiKey, forHTTPHeaderField: "Authorization")
                } else {
                    request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                }
            }
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 86400
            let session = URLSession(configuration: config)
            
            do {
                let (bytes, response) = try await session.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    DebugLogger.shared.log("[LiveSync] SSE connection status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.isConnected = true
                    self.isConnecting = false
                    self.retryCount = 0
                }
                DebugLogger.shared.log("[LiveSync] Live sync connected to server!")
                
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
                    DebugLogger.shared.log("[LiveSync] Connection interrupted: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.isConnected = false
                self.isConnecting = false
            }
            
            // Reconnect logic with exponential backoff if still supposed to run
            if self.shouldRun && !Task.isCancelled {
                self.retryCount += 1
                let delay = min(pow(2.0, Double(min(self.retryCount, 5))), 20.0)
                DebugLogger.shared.log("[LiveSync] Reconnecting in \(Int(delay))s...")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if self.shouldRun {
                    self.connect()
                }
            }
        }
    }
    
    // MARK: - Handle Incoming Event
    
    private func handleEventData(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        
        do {
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let type = (obj["type"] as? String) ?? "event"
                
                // Ignore initial connection ping
                if obj["connected"] != nil || type == "ping" {
                    return
                }
                
                DispatchQueue.main.async {
                    self.lastEventDescription = "Update: \(type)"
                    self.lastEventTime = Date()
                    DebugLogger.shared.log("[LiveSync] Received event: \(type) -> Auto-refreshing view")
                    
                    // Post notification to trigger instant UI refresh in file browser
                    NotificationCenter.default.post(
                        name: .fluxCloudFilesDidChange,
                        object: nil,
                        userInfo: obj
                    )
                }
            }
        } catch {
            // Non-JSON line or keepalive
        }
    }
}
