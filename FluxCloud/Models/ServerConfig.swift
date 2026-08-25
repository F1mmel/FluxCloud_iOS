import Foundation

/// Model for stored server configuration
public struct ServerConfig: Codable, Equatable {
    public var serverUrl: String
    public var apiKey: String
    public var username: String
    
    public init(serverUrl: String = "", apiKey: String = "", username: String = "") {
        self.serverUrl = serverUrl
        self.apiKey = apiKey
        self.username = username
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

/// Response model for /api/auth/login
public struct AuthLoginResponse: Codable {
    public let success: Bool
    public let token: String?
    public let user: AuthUserInfo?
    public let requiresPasswordSetup: Bool?
    public let message: String?
}

public struct AuthUserInfo: Codable {
    public let id: String
    public let username: String
    public let role: String?
}

/// Response model for /api/upload
public struct UploadResponse: Codable {
    public let success: Bool
    public let files: [UploadedFileInfo]?
    public let message: String?
}

public struct UploadedFileInfo: Codable {
    public let name: String
    public let relativePath: String
    public let url: String?
    public let mimeType: String?
}

/// Model for real-time SSE events
public struct LiveEventPayload: Codable {
    public let type: String
    public let username: String?
    public let path: String?
    public let targetPath: String?
    public let timestamp: Double?
}
