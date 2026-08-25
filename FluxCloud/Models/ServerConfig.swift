import Foundation

/// Model for stored server configuration
public struct ServerConfig: Codable, Equatable {
    public var serverUrl: String
    public var apiKey: String
    
    public init(serverUrl: String = "", apiKey: String = "") {
        self.serverUrl = serverUrl
        self.apiKey = apiKey
    }
    
    /// Normalizes and formats the server URL supporting both HTTP and HTTPS
    public static func formatBaseURL(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return "" }
        
        let lower = url.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            // Check if it's a local IP, localhost, or has a port specified -> default to http://
            let hasPort = url.contains(":")
            let isLocal = lower.contains("localhost") || lower.hasSuffix(".local") || lower.hasPrefix("192.168.") || lower.hasPrefix("10.") || lower.hasPrefix("172.") || lower.hasPrefix("127.0.0.1")
            
            if hasPort || isLocal {
                url = "http://" + url
            } else {
                url = "https://" + url
            }
        }
        
        // Remove trailing slashes
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }
    
    public var cleanedURLString: String {
        return ServerConfig.formatBaseURL(serverUrl)
    }
    
    public var isValid: Bool {
        return !serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Response model for /api/verify-key
public struct VerifyKeyResponse: Codable {
    public let valid: Bool
}
