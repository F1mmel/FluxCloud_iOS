import Foundation
import SwiftUI

public class AuthManager: ObservableObject {
    private let kServerUrlKey = "fluxcloud_server_url"
    private let kApiKeyKey = "fluxcloud_api_key"
    private let kIsLoggedInKey = "fluxcloud_is_logged_in"
    
    @Published public var config: ServerConfig
    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    public init() {
        let savedUrl = UserDefaults.standard.string(forKey: kServerUrlKey) ?? ""
        let savedKey = UserDefaults.standard.string(forKey: kApiKeyKey) ?? ""
        let wasLoggedIn = UserDefaults.standard.bool(forKey: kIsLoggedInKey)
        
        self.config = ServerConfig(serverUrl: savedUrl, apiKey: savedKey)
        if wasLoggedIn && !savedUrl.isEmpty {
            self.isAuthenticated = true
        }
    }
    
    @MainActor
    public func login(serverUrl: String, apiKey: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        let tempConfig = ServerConfig(serverUrl: serverUrl, apiKey: apiKey)
        let cleanedUrl = tempConfig.cleanedURLString
        
        guard !cleanedUrl.isEmpty else {
            isLoading = false
            errorMessage = "Please enter a valid server address."
            return false
        }
        
        do {
            let isValid = try await APIService.shared.verifyKey(serverUrl: cleanedUrl, apiKey: apiKey)
            if isValid {
                self.config = ServerConfig(serverUrl: cleanedUrl, apiKey: apiKey)
                self.isAuthenticated = true
                
                UserDefaults.standard.set(cleanedUrl, forKey: kServerUrlKey)
                UserDefaults.standard.set(apiKey, forKey: kApiKeyKey)
                UserDefaults.standard.set(true, forKey: kIsLoggedInKey)
                
                isLoading = false
                return true
            } else {
                isLoading = false
                errorMessage = "API Key was rejected by the server."
                return false
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    @MainActor
    public func logout() {
        isAuthenticated = false
        errorMessage = nil
        UserDefaults.standard.set(false, forKey: kIsLoggedInKey)
    }
}
