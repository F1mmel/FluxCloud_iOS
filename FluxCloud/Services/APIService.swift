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
            return "Ungültige Server-URL. Bitte überprüfe die Adresse."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        case .unauthorized:
            return "Ungültiger API-Key oder Zugriff verweigert."
        case .serverError(let code, let msg):
            return "Serverfehler (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Datenverarbeitungsfehler: \(msg)"
        }
    }
}

public class APIService: ObservableObject {
    public static let shared = APIService()
    
    private let urlSession: URLSession
    
    public init(session: URLSession = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - Verify Key / Connection Check
    
    public func verifyKey(serverUrl: String, apiKey: String) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        
        guard let url = URL(string: "\(base)/api/verify-key") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let payload: [String: String] = ["key": apiKey]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Ungültige Antwort vom Server")
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw APIError.serverError(httpResponse.statusCode, msg)
            }
            
            let decoded = try JSONDecoder().decode(VerifyKeyResponse.self, from: data)
            return decoded.valid
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
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
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Ungültige Antwort vom Server")
            }
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw APIError.serverError(httpResponse.statusCode, msg)
            }
            
            let files = try JSONDecoder().decode([FileItem].self, from: data)
            return files
        } catch let err as APIError {
            throw err
        } catch let decErr as DecodingError {
            throw APIError.decodingError("Fehler beim Parsen der Serverdaten: \(decErr.localizedDescription)")
        } catch {
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
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, "Download fehlgeschlagen")
        }
        
        // Move to persistent temp file with proper filename
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
