import SwiftUI

public struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var debugLogger = DebugLogger.shared
    
    @State private var serverUrl: String = ""
    @State private var apiKey: String = ""
    @State private var isSecureApiKey: Bool = true
    @State private var copiedLogsNotice: Bool = false
    
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
                    VStack(spacing: 24) {
                        Spacer().frame(height: 20)
                        
                        // App Logo & Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 76, height: 76)
                                    .shadow(color: Color.cyan.opacity(0.35), radius: 16, x: 0, y: 6)
                                
                                Image(systemName: "cloud.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                            }
                            
                            Text("FluxCloud")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Nativer iOS Client")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Input Card
                        VStack(spacing: 18) {
                            // Server URL Field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Server Adresse", systemImage: "server.rack")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    TextField("http://10.116.4.79:3033", text: $serverUrl)
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
                                .padding(14)
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
                                    .font(.system(size: 13, weight: .semibold))
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
                                .padding(14)
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
                                        Text("Verbinde...")
                                            .font(.headline)
                                    } else {
                                        Text("Verbinden & Anmelden")
                                            .font(.headline)
                                        Image(systemName: "arrow.right")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(authManager.isLoading || serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        }
                        .padding(20)
                        .background(Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.8))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        
                        // Live Debug Log Terminal Box
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Live Verbindungs-Log", systemImage: "terminal.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                if !debugLogger.logs.isEmpty {
                                    Button(action: {
                                        UIPasteboard.general.string = debugLogger.logs.joined(separator: "\n")
                                        copiedLogsNotice = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            copiedLogsNotice = false
                                        }
                                    }) {
                                        Text(copiedLogsNotice ? "Kopiert!" : "Kopieren")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.12))
                                            .foregroundColor(.cyan)
                                            .cornerRadius(6)
                                    }
                                    
                                    Button(action: {
                                        debugLogger.clear()
                                    }) {
                                        Text("Leeren")
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.12))
                                            .foregroundColor(.gray)
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 4) {
                                        if debugLogger.logs.isEmpty {
                                            Text("Noch keine Verbindungsversuche. Drücke auf 'Verbinden', um die Logs live zu sehen.")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.gray.opacity(0.7))
                                                .padding(.vertical, 8)
                                        } else {
                                            ForEach(Array(debugLogger.logs.enumerated()), id: \.offset) { index, line in
                                                Text(line)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(logColor(for: line))
                                                    .id(index)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                }
                                .frame(height: 160)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .onChange(of: debugLogger.logs.count) { _ in
                                    if !debugLogger.logs.isEmpty {
                                        proxy.scrollTo(debugLogger.logs.count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer().frame(height: 20)
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
    
    private func logColor(for line: String) -> Color {
        if line.contains("FEHLER") || line.contains("fehlgeschlagen") {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
        if line.contains("Statuscode: HTTP 200") || line.contains("erfolgreich") || line.contains("Gültig") {
            return Color(red: 0.4, green: 1.0, blue: 0.5)
        }
        if line.contains("Sende") || line.contains("Starte") {
            return Color(red: 0.4, green: 0.8, blue: 1.0)
        }
        return Color(red: 0.9, green: 0.9, blue: 0.9)
    }
}
