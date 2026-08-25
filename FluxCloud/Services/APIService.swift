import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case networkError(String)
    case unauthorized
    case serverError(Int, String)
    case decodingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server address. Please verify the URL."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .unauthorized:
            return "Invalid API Key or access denied."
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Data decoding error: \(msg)"
        }
    }
}

public class APIService: ObservableObject {
    public static let shared = APIService()
    
    private let urlSession: URLSession
    
    public init(session: URLSession = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - Verify Key / Connection Check
    
    public func verifyKey(serverUrl: String, apiKey: String) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        DebugLogger.shared.log("Starting connection check...")
        DebugLogger.shared.log("Server URL: \(base)")
        
        guard let url = URL(string: "\(base)/api/verify-key") else {
            DebugLogger.shared.log("ERROR: Could not parse URL: \(base)/api/verify-key")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let payload: [String: String] = ["key": apiKey]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        DebugLogger.shared.log("Sending POST to \(url.absoluteString) (Timeout: 8s)...")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                DebugLogger.shared.log("ERROR: Invalid response received")
                throw APIError.networkError("Invalid response from server")
            }
            
            DebugLogger.shared.log("Status: HTTP \(httpResponse.statusCode)")
            let rawResponse = String(data: data, encoding: .utf8) ?? "<undecodable>"
            DebugLogger.shared.log("Response: \(rawResponse)")
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                DebugLogger.shared.log("ERROR: Unauthorized API Key (HTTP \(httpResponse.statusCode))")
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode == 404 {
                // Fallback attempt with GET /api/files
                DebugLogger.shared.log("Endpoint /api/verify-key not found (404). Trying /api/files...")
                return try await verifyFallbackFiles(base: base, apiKey: apiKey)
            }
            
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                DebugLogger.shared.log("ERROR: Server returned HTTP \(httpResponse.statusCode)")
                throw APIError.serverError(httpResponse.statusCode, rawResponse)
            }
            
            let decoded = try JSONDecoder().decode(VerifyKeyResponse.self, from: data)
            DebugLogger.shared.log("Key validation: \(decoded.valid ? "Valid" : "Invalid")")
            return decoded.valid
        } catch let err as APIError {
            throw err
        } catch {
            let nsErr = error as NSError
            DebugLogger.shared.log("Network error (\(nsErr.domain) Code \(nsErr.code)): \(error.localizedDescription)")
            
            // Try fallback GET /api/files directly
            DebugLogger.shared.log("Attempting fallback check (/api/files)...")
            do {
                return try await verifyFallbackFiles(base: base, apiKey: apiKey)
            } catch {
                DebugLogger.shared.log("Fallback check also failed: \(error.localizedDescription)")
                throw APIError.networkError(error.localizedDescription)
            }
        }
    }
    
    private func verifyFallbackFiles(base: String, apiKey: String) async throws -> Bool {
        guard let url = URL(string: "\(base)/api/files") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        DebugLogger.shared.log("Fallback /api/files Status: HTTP \(httpResponse.statusCode)")
        if httpResponse.statusCode == 200 {
            DebugLogger.shared.log("Connection via /api/files verified successfully!")
            return true
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.unauthorized
        }
        throw APIError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
    }
    
    // MARK: - Fetch Files
    
    public func fetchFiles(serverUrl: String, apiKey: String, path: String, category: String = "all", search: String = "") async throws -> [FileItem] {
        let base = ServerConfig.formatBaseURL(serverUrl)
        
        var components = URLComponents(string: "\(base)/api/files")
        guard components != nil else {
            throw APIError.invalidURL
        }
        
        var queryItems: [URLQueryItem] = []
        if !path.isEmpty {
            queryItems.append(URLQueryItem(name: "path", value: path))
        }
        if category != "all" {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        DebugLogger.shared.log("Fetching files from \(url.absoluteString)...")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response from server")
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw APIError.serverError(httpResponse.statusCode, msg)
            }
            
            let files = try JSONDecoder().decode([FileItem].self, from: data)
            DebugLogger.shared.log("Loaded \(files.count) items")
            return files
        } catch let err as APIError {
            throw err
        } catch let decErr as DecodingError {
            DebugLogger.shared.log("JSON parsing error: \(decErr.localizedDescription)")
            throw APIError.decodingError("Error parsing server response: \(decErr.localizedDescription)")
        } catch {
            DebugLogger.shared.log("Load error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - URLs for Media & Thumbnails
    
    public func getDirectDownloadURL(serverUrl: String, apiKey: String, for item: FileItem) -> URL? {
        guard let urlString = item.url else { return nil }
        let base = ServerConfig.formatBaseURL(serverUrl)
        
        let pathPart = urlString.hasPrefix("/") ? urlString : "/\(urlString)"
        var fullString = "\(base)\(pathPart)"
        
        if !apiKey.isEmpty {
            let separator = fullString.contains("?") ? "&" : "?"
            let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
            fullString += "\(separator)key=\(encodedKey)"
        }
        
        return URL(string: fullString)
    }
    
    public func getThumbnailURL(serverUrl: String, apiKey: String, for item: FileItem) -> URL? {
        guard let thumbString = item.thumbnailUrl else { return nil }
        let base = ServerConfig.formatBaseURL(serverUrl)
        
        let pathPart = thumbString.hasPrefix("/") ? thumbString : "/\(thumbString)"
        var fullString = "\(base)\(pathPart)"
        
        if !apiKey.isEmpty {
            let separator = fullString.contains("?") ? "&" : "?"
            let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
            fullString += "\(separator)key=\(encodedKey)"
        }
        
        return URL(string: fullString)
    }
    
    // MARK: - Download File to Temp Local Storage
    
    public func downloadFileToLocal(serverUrl: String, apiKey: String, item: FileItem, progress: ((Double) -> Void)? = nil) async throws -> URL {
        guard let downloadUrl = getDirectDownloadURL(serverUrl: serverUrl, apiKey: apiKey, for: item) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: downloadUrl)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (tempLocalURL, response) = try await urlSession.download(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, "Download failed")
        }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("FluxCloudDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: tempDir.path) {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        let destinationURL = tempDir.appendingPathComponent(item.name)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.moveItem(at: tempLocalURL, to: destinationURL)
        return destinationURL
    }
}
