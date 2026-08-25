import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case networkError(String)
    case unauthorized
    case serverError(Int, String)
    case decodingError(String)
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige Server-Adresse. Bitte überprüfe die URL."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        case .unauthorized:
            return "Zugriff verweigert. Bitte überprüfe Benutzername, Passwort oder API-Key."
        case .serverError(let code, let msg):
            return "Server-Fehler (\(code)): \(msg)"
        case .decodingError(let msg):
            return "Datenverarbeitungsfehler: \(msg)"
        case .custom(let msg):
            return msg
        }
    }
}

public class APIService: ObservableObject {
    public static let shared = APIService()
    
    private let urlSession: URLSession
    
    public init(session: URLSession = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - Server Reachability & Status Check
    
    public func checkServerReachable(serverUrl: String) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        DebugLogger.shared.log("Checking server reachability for: \(base)")
        
        guard let url = URL(string: "\(base)/api/config") ?? URL(string: base) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                DebugLogger.shared.log("Server responded with HTTP \(httpResponse.statusCode)")
                return httpResponse.statusCode < 500
            }
            return true
        } catch {
            // Fallback check on root or verify-key
            if let fallbackUrl = URL(string: "\(base)/api/verify-key") {
                var fbReq = URLRequest(url: fallbackUrl)
                fbReq.httpMethod = "POST"
                fbReq.timeoutInterval = 8
                do {
                    let (_, response) = try await urlSession.data(for: fbReq)
                    if let httpResponse = response as? HTTPURLResponse {
                        return httpResponse.statusCode < 500
                    }
                } catch {}
            }
            DebugLogger.shared.log("Server unreachable: \(error.localizedDescription)")
            throw APIError.networkError("Server nicht erreichbar (\(error.localizedDescription))")
        }
    }
    
    // MARK: - User Login (Username & Password)
    
    public func loginWithCredentials(serverUrl: String, username: String, password: String) async throws -> (token: String, username: String) {
        let base = ServerConfig.formatBaseURL(serverUrl)
        DebugLogger.shared.log("Logging in user '\(username)' on \(base)...")
        
        guard let url = URL(string: "\(base)/api/auth/login") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload: [String: String] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Ungültige Serverantwort")
            }
            
            let rawStr = String(data: data, encoding: .utf8) ?? ""
            DebugLogger.shared.log("Login HTTP \(httpResponse.statusCode): \(rawStr)")
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                throw APIError.serverError(httpResponse.statusCode, rawStr)
            }
            
            let decoded = try JSONDecoder().decode(AuthLoginResponse.self, from: data)
            if !decoded.success {
                throw APIError.custom(decoded.message ?? "Anmeldung fehlgeschlagen.")
            }
            
            let userToken = decoded.token ?? ""
            let loggedInUser = decoded.user?.username ?? username
            
            // If token is empty (cookie-only server), encode Basic Auth string as token fallback
            let finalToken: String
            if !userToken.isEmpty {
                finalToken = userToken
            } else {
                let basicCreds = "\(username):\(password)"
                finalToken = "Basic " + (basicCreds.data(using: .utf8)?.base64EncodedString() ?? "")
            }
            
            return (token: finalToken, username: loggedInUser)
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Verify Key / Connection Check (API Key)
    
    public func verifyKey(serverUrl: String, apiKey: String) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        DebugLogger.shared.log("Starting connection check for API Key...")
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
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let payload: [String: String] = ["key": apiKey]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response from server")
            }
            
            DebugLogger.shared.log("Status: HTTP \(httpResponse.statusCode)")
            let rawResponse = String(data: data, encoding: .utf8) ?? "<undecodable>"
            DebugLogger.shared.log("Response: \(rawResponse)")
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode == 404 {
                // Fallback attempt with GET /api/files
                DebugLogger.shared.log("Endpoint /api/verify-key not found (404). Trying /api/files...")
                return try await verifyFallbackFiles(base: base, apiKey: apiKey)
            }
            
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                throw APIError.serverError(httpResponse.statusCode, rawResponse)
            }
            
            let decoded = try JSONDecoder().decode(VerifyKeyResponse.self, from: data)
            return decoded.valid
        } catch let err as APIError {
            throw err
        } catch {
            return try await verifyFallbackFiles(base: base, apiKey: apiKey)
        }
    }
    
    private func verifyFallbackFiles(base: String, apiKey: String) async throws -> Bool {
        guard let url = URL(string: "\(base)/api/files") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
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
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
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
            return files
        } catch let err as APIError {
            throw err
        } catch let decErr as DecodingError {
            throw APIError.decodingError("Error parsing server response: \(decErr.localizedDescription)")
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Upload File (Multipart Form Data)
    
    public func uploadFile(
        serverUrl: String,
        apiKey: String,
        path: String,
        filename: String,
        data: Data,
        mimeType: String = "application/octet-stream",
        progress: ((Double) -> Void)? = nil
    ) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        
        var components = URLComponents(string: "\(base)/api/upload")
        if !path.isEmpty {
            components?.queryItems = [URLQueryItem(name: "path", value: path)]
        }
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        // Build multipart body
        var body = Data()
        let safeFilename = filename.replacingOccurrences(of: "\"", with: "_")
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        DebugLogger.shared.log("Uploading '\(filename)' (\(data.count) bytes) to '\(path)'...")
        progress?(0.1)
        
        let (responseData, response) = try await urlSession.upload(for: request, from: body)
        progress?(1.0)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid upload response")
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let msg = String(data: responseData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw APIError.serverError(httpResponse.statusCode, msg)
        }
        
        DebugLogger.shared.log("Upload of '\(filename)' completed successfully!")
        return true
    }
    
    // MARK: - Create Folder
    
    public func createFolder(serverUrl: String, apiKey: String, path: String, name: String) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        guard let url = URL(string: "\(base)/api/folder") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let payload: [String: String] = ["path": path, "name": name]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let msg = String(data: data, encoding: .utf8) ?? "Failed to create folder"
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, msg)
        }
        
        return true
    }
    
    // MARK: - Rename Item
    
    public func renameItem(serverUrl: String, apiKey: String, path: String, newName: String) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        guard let url = URL(string: "\(base)/api/rename") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let payload: [String: String] = ["path": path, "newName": newName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let msg = String(data: data, encoding: .utf8) ?? "Failed to rename item"
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, msg)
        }
        
        return true
    }
    
    // MARK: - Delete Items
    
    public func deleteItems(serverUrl: String, apiKey: String, paths: [String], permanent: Bool = false) async throws -> Bool {
        let base = ServerConfig.formatBaseURL(serverUrl)
        guard let url = URL(string: "\(base)/api/delete") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if !apiKey.isEmpty {
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let payload: [String: Any] = ["paths": paths, "permanent": permanent]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let msg = String(data: data, encoding: .utf8) ?? "Failed to delete item(s)"
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, msg)
        }
        
        return true
    }
    
    // MARK: - URLs for Media & Thumbnails
    
    public func getDirectDownloadURL(serverUrl: String, apiKey: String, for item: FileItem) -> URL? {
        guard let urlString = item.url else { return nil }
        let base = ServerConfig.formatBaseURL(serverUrl)
        
        let pathPart = urlString.hasPrefix("/") ? urlString : "/\(urlString)"
        var fullString = "\(base)\(pathPart)"
        
        if !apiKey.isEmpty && !apiKey.hasPrefix("Basic ") {
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
        
        if !apiKey.isEmpty && !apiKey.hasPrefix("Basic ") {
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
            if apiKey.hasPrefix("Basic ") {
                request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (tempLocalURL, response) = try await urlSession.download(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500, "Download fehlgeschlagen")
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
