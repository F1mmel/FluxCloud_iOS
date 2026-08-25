import SwiftUI

public struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var debugLogger = DebugLogger.shared
    
    // Login Step State (1: Server URL, 2: Auth Method)
    @State private var currentStep: Int = 1
    
    // Step 1 Form
    @State private var serverUrl: String = ""
    
    // Step 2 Form
    @State private var authMethod: AuthMethod = .credentials
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSecurePassword: Bool = true
    @State private var apiKey: String = ""
    @State private var isSecureApiKey: Bool = true
    
    @State private var copiedLogsNotice: Bool = false
    @State private var showDebugLog: Bool = false
    
    enum AuthMethod: String, CaseIterable {
        case credentials = "Login"
        case apiKey = "API Key"
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.07, green: 0.09, blue: 0.15),
                        Color(red: 0.03, green: 0.04, blue: 0.07)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 12)
                        
                        // App Logo & Header
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 72, height: 72)
                                    .shadow(color: Color.cyan.opacity(0.35), radius: 14, x: 0, y: 6)
                                
                                Image(systemName: "cloud.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 38, height: 38)
                                    .foregroundColor(.white)
                            }
                            
                            Text("FluxCloud")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(currentStep == 1 ? "Server-Adresse eingeben" : "Am Cloud-Server anmelden")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Step 1: Server URL
                        if currentStep == 1 {
                            step1ServerView
                                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                        } else {
                            // Step 2: Auth (Credentials or API Key)
                            step2AuthView
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                        }
                        
                        // Debug Log Toggle & Terminal Box
                        debugLogSection
                        
                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if serverUrl.isEmpty {
                    serverUrl = authManager.config.serverUrl
                }
                if apiKey.isEmpty {
                    apiKey = authManager.config.apiKey
                }
                if username.isEmpty {
                    username = authManager.config.username
                }
            }
        }
    }
    
    // MARK: - Step 1: Server URL Input View
    
    private var step1ServerView: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Server Adresse", systemImage: "server.rack")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
                
                HStack {
                    ZStack(alignment: .leading) {
                        if serverUrl.isEmpty {
                            Text(verbatim: "https://cloud.example.com")
                                .foregroundColor(Color.gray.opacity(0.65))
                                .font(.body)
                        }
                        TextField("", text: $serverUrl)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                    }
                    
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
                
                Text("Gib die Domain oder IP deines FluxCloud CDN Servers ein.")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.horizontal, 2)
            }
            
            // Error Message
            if let error = authManager.errorMessage {
                errorBanner(error)
            }
            
            // "Weiter" Button
            Button(action: {
                handleStep1Continue()
            }) {
                HStack(spacing: 10) {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Verbindung prüfen...")
                            .font(.headline)
                    } else {
                        Text("Weiter")
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
        .background(Color(red: 0.11, green: 0.13, blue: 0.19).opacity(0.85))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Step 2: Auth Selection View
    
    private var step2AuthView: some View {
        VStack(spacing: 18) {
            // Connected Server Info Badge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Server")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(ServerConfig.formatBaseURL(serverUrl))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cyan)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep = 1
                    }
                }) {
                    Text("Ändern")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.35))
            .cornerRadius(10)
            
            // Picker Switcher (Username/Password vs API Key)
            Picker("Anmeldeart", selection: $authMethod) {
                Text("Benutzername").tag(AuthMethod.credentials)
                Text("API Key").tag(AuthMethod.apiKey)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)
            
            if authMethod == .credentials {
                // Username & Password Fields
                VStack(alignment: .leading, spacing: 8) {
                    Label("Benutzername", systemImage: "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    HStack {
                        TextField("admin", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Passwort", systemImage: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    HStack {
                        if isSecurePassword {
                            SecureField("Passwort", text: $password)
                                .textContentType(.password)
                                .foregroundColor(.white)
                        } else {
                            TextField("Passwort", text: $password)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: { isSecurePassword.toggle() }) {
                            Image(systemName: isSecurePassword ? "eye.slash" : "eye")
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
            } else {
                // API Key Field
                VStack(alignment: .leading, spacing: 8) {
                    Label("API Key", systemImage: "key.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    HStack {
                        if isSecureApiKey {
                            SecureField("fc_...", text: $apiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)
                        } else {
                            TextField("fc_...", text: $apiKey)
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
            }
            
            // Error Message
            if let error = authManager.errorMessage {
                errorBanner(error)
            }
            
            // Submit Button
            Button(action: {
                handleLoginSubmit()
            }) {
                HStack(spacing: 10) {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Anmelden...")
                            .font(.headline)
                    } else {
                        Text(authMethod == .credentials ? "Anmelden" : "Mit API-Key verbinden")
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
            .disabled(authManager.isLoading)
        }
        .padding(20)
        .background(Color(red: 0.11, green: 0.13, blue: 0.19).opacity(0.85))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Actions
    
    private func handleStep1Continue() {
        Task {
            let reachable = await authManager.checkServer(serverUrl: serverUrl)
            // Even if reachable check is uncertain, proceed to step 2 if URL is valid
            if reachable || !ServerConfig.formatBaseURL(serverUrl).isEmpty {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentStep = 2
                }
            }
        }
    }
    
    private func handleLoginSubmit() {
        Task {
            if authMethod == .credentials {
                _ = await authManager.loginWithCredentials(
                    serverUrl: serverUrl,
                    username: username,
                    password: password
                )
            } else {
                _ = await authManager.loginWithApiKey(
                    serverUrl: serverUrl,
                    apiKey: apiKey
                )
            }
        }
    }
    
    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
            
            Text(text)
                .font(.footnote)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Debug Log Terminal Box
    
    private var debugLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation {
                    showDebugLog.toggle()
                }
            }) {
                HStack {
                    Label("Verbindungsprotokoll", systemImage: "terminal.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: showDebugLog ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            
            if showDebugLog {
                HStack {
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
                                Text("Keine Verbindungsversuche protokolliert.")
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
                    .frame(height: 140)
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
        }
        .padding(.horizontal, 16)
    }
    
    private func logColor(for line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("fehler") || lower.contains("failed") {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
        if lower.contains("http 200") || lower.contains("success") || lower.contains("erfolg") || lower.contains("valid") {
            return Color(red: 0.4, green: 1.0, blue: 0.5)
        }
        if lower.contains("sending") || lower.contains("start") || lower.contains("prüfen") {
            return Color(red: 0.4, green: 0.8, blue: 1.0)
        }
        return Color(red: 0.9, green: 0.9, blue: 0.9)
    }
}
