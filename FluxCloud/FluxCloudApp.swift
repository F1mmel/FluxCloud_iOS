import SwiftUI

@main
struct FluxCloudApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    NavigationStack {
                        FileBrowserView()
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
        }
    }
}
