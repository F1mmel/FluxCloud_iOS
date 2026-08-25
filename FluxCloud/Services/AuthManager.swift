import Foundation
import SwiftUI

public class AuthManager: ObservableObject {
    private let kServerUrlKey = "fluxcloud_server_url"
    private let kApiKeyKey = "fluxcloud_api_key"
    private let kUsernameKey = "fluxcloud_username"
    private let kIsLoggedInKey = "fluxcloud_is_logged_in"
    
    @Published public var config: ServerConfig
    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    public init() {
        let savedUrl = UserDefaults.standard.string(forKey: kServerUrlKey) ?? ""
        let savedKey = UserDefaults.standard.string(forKey: kApiKeyKey) ?? ""
        let savedUser = UserDefaults.standard.string(forKey: kUsernameKey) ?? ""
        let wasLoggedIn = UserDefaults.standard.bool(forKey: kIsLoggedInKey)
        
        self.config = ServerConfig(serverUrl: savedUrl, apiKey: savedKey, username: savedUser)
        if wasLoggedIn && !savedUrl.isEmpty {
            self.isAuthenticated = true
            // Start live sync automatically
            LiveSyncManager.shared.start(serverUrl: savedUrl, apiKey: savedKey)
        }
    }
    
    // MARK: - Server Reachability Check
    
    @MainActor
    public func checkServer(serverUrl: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        let cleanedUrl = ServerConfig.formatBaseURL(serverUrl)
        guard !cleanedUrl.isEmpty else {
            isLoading = false
            errorMessage = "Bitte gib eine gültige Server-Adresse ein."
            return false
        }
        
        do {
            let isReachable = try await APIService.shared.checkServerReachable(serverUrl: cleanedUrl)
            isLoading = false
            return isReachable
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Login with Username & Password
    
    @MainActor
    public func loginWithCredentials(serverUrl: String, username: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        let cleanedUrl = ServerConfig.formatBaseURL(serverUrl)
        guard !cleanedUrl.isEmpty else {
            isLoading = false
            errorMessage = "Bitte gib eine gültige Server-Adresse ein."
            return false
        }
        
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isLoading = false
            errorMessage = "Bitte gib einen Benutzernamen ein."
            return false
        }
        
        do {
            let result = try await APIService.shared.loginWithCredentials(
                serverUrl: cleanedUrl,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            
            self.config = ServerConfig(serverUrl: cleanedUrl, apiKey: result.token, username: result.username)
            self.isAuthenticated = true
            
            UserDefaults.standard.set(cleanedUrl, forKey: kServerUrlKey)
            UserDefaults.standard.set(result.token, forKey: kApiKeyKey)
            UserDefaults.standard.set(result.username, forKey: kUsernameKey)
            UserDefaults.standard.set(true, forKey: kIsLoggedInKey)
            
            // Start live sync
            LiveSyncManager.shared.start(serverUrl: cleanedUrl, apiKey: result.token)
            
            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Login with API Key
    
    @MainActor
    public func loginWithApiKey(serverUrl: String, apiKey: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        let cleanedUrl = ServerConfig.formatBaseURL(serverUrl)
        guard !cleanedUrl.isEmpty else {
            isLoading = false
            errorMessage = "Bitte gib eine gültige Server-Adresse ein."
            return false
        }
        
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let isValid = try await APIService.shared.verifyKey(serverUrl: cleanedUrl, apiKey: trimmedKey)
            if isValid {
                self.config = ServerConfig(serverUrl: cleanedUrl, apiKey: trimmedKey, username: "admin")
                self.isAuthenticated = true
                
                UserDefaults.standard.set(cleanedUrl, forKey: kServerUrlKey)
                UserDefaults.standard.set(trimmedKey, forKey: kApiKeyKey)
                UserDefaults.standard.set("admin", forKey: kUsernameKey)
                UserDefaults.standard.set(true, forKey: kIsLoggedInKey)
                
                // Start live sync
                LiveSyncManager.shared.start(serverUrl: cleanedUrl, apiKey: trimmedKey)
                
                isLoading = false
                return true
            } else {
                isLoading = false
                errorMessage = "API Key wurde vom Server abgelehnt."
                return false
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // Legacy support
    @MainActor
    public func login(serverUrl: String, apiKey: String) async -> Bool {
        return await loginWithApiKey(serverUrl: serverUrl, apiKey: apiKey)
    }
    
    // MARK: - Logout
    
    @MainActor
    public func logout() {
        isAuthenticated = false
        errorMessage = nil
        LiveSyncManager.shared.stop()
        UserDefaults.standard.set(false, forKey: kIsLoggedInKey)
    }
}
