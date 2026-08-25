import SwiftUI

public struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var serverUrl: String = ""
    @State private var apiKey: String = ""
    @State private var isSecureApiKey: Bool = true
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.08, green: 0.10, blue: 0.16),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 40)
                        
                        // App Logo & Header
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 88, height: 88)
                                    .shadow(color: Color.cyan.opacity(0.35), radius: 18, x: 0, y: 8)
                                
                                Image(systemName: "cloud.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 46, height: 46)
                                    .foregroundColor(.white)
                            }
                            
                            Text("FluxCloud")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Nativer iOS Client für deine persönliche Cloud")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Input Card
                        VStack(spacing: 20) {
                            // Server URL Field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Server Adresse", systemImage: "server.rack")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    TextField("https://mein-fluxcloud.de", text: $serverUrl)
                                        .textContentType(.URL)
                                        .keyboardType(.URL)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .foregroundColor(.white)
                                    
                                    if !serverUrl.isEmpty {
                                        Button(action: { serverUrl = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            
                            // API Key Field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("API-Key", systemImage: "key.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    if isSecureApiKey {
                                        SecureField("API-Schlüssel eingeben", text: $apiKey)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .foregroundColor(.white)
                                    } else {
                                        TextField("API-Schlüssel eingeben", text: $apiKey)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Button(action: { isSecureApiKey.toggle() }) {
                                        Image(systemName: isSecureApiKey ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            
                            // Error Message
                            if let error = authManager.errorMessage {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.subheadline)
                                    
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Connect Button
                            Button(action: {
                                Task {
                                    _ = await authManager.login(serverUrl: serverUrl, apiKey: apiKey)
                                }
                            }) {
                                HStack(spacing: 10) {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Verbinden & Anmelden")
                                            .font(.headline)
                                        Image(systemName: "arrow.right")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .disabled(authManager.isLoading || serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        }
                        .padding(24)
                        .background(Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.7))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                serverUrl = authManager.config.serverUrl
                apiKey = authManager.config.apiKey
            }
        }
    }
}
