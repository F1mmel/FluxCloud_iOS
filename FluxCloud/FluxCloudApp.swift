import SwiftUI

@main
struct FluxCloudApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var updateManager = UpdateManager.shared
    
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
            .environmentObject(updateManager)
            .sheet(isPresented: $updateManager.showUpdateSheet) {
                UpdateSheet()
            }
            .task {
                await updateManager.checkForUpdates()
            }
        }
    }
}
