import Foundation

/// Model for stored server configuration
public struct ServerConfig: Codable, Equatable {
    public var serverUrl: String
    public var apiKey: String
    
    public init(serverUrl: String = "", apiKey: String = "") {
        self.serverUrl = serverUrl
        self.apiKey = apiKey
    }
    
    public var cleanedURLString: String {
        var url = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty && !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
            url = "https://" + url
        }
        // Remove trailing slash
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }
    
    public var isValid: Bool {
        return !serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Response model for /api/verify-key
public struct VerifyKeyResponse: Codable {
    public let valid: Bool
}
