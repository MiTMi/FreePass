import SwiftUI
import SwiftData
import Network

/// Routes between onboarding, unlock, and main vault views.
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isFirstLaunch {
                OnboardingView()
            } else if !appState.isUnlocked {
                UnlockView()
            } else {
                VaultListView()
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .background(Color.fpBackground)
        .animation(.easeInOut(duration: 0.4), value: appState.isUnlocked)
        .animation(.easeInOut(duration: 0.4), value: appState.isFirstLaunch)
        .onAppear {
            let extensionEnabled = UserDefaults.standard.object(forKey: "extensionEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "extensionEnabled")
            if extensionEnabled {
                startExtensionServer()
            }
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func startExtensionServer() {
        ExtensionServer.shared.credentialsProvider = { domain in
            // Must be unlocked to return credentials
            guard let key = appState.derivedKey else { return [] }
            
            var results: [[String: String]] = []
            do {
                let items = try modelContext.fetch(FetchDescriptor<VaultItem>())
                let cleanDomain = domain.lowercased().replacingOccurrences(of: "www.", with: "")
                
                for item in items {
                    let urlString = item.url.lowercased()
                    if !urlString.isEmpty && (domain.isEmpty || urlString.contains(cleanDomain) || cleanDomain.contains(urlString)) {
                        if let pwd = item.decryptedPassword(using: key) {
                            results.append([
                                "title": item.title,
                                "username": item.username,
                                "password": pwd
                            ])
                        }
                    }
                }
            } catch {
                print("Failed to fetch extension vault items: \(error)")
            }
            return results
        }
        ExtensionServer.shared.start()
    }
}

final class ExtensionServer: @unchecked Sendable {
    static let shared = ExtensionServer()
    private var listener: NWListener?
    
    // A callback to fetch credentials dynamically, provided by AppState
    var credentialsProvider: ((String) -> [[String: String]])?
    
    // Stores the domain that the user just clicked "Open & Fill" for in the native app
    var pendingAutoFillDomain: String?
    
    func start() {
        do {
            listener = try NWListener(using: .tcp, on: 54321)
            listener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                    guard let data = data, let requestStr = String(data: data, encoding: .utf8) else {
                        connection.cancel()
                        return
                    }
                    
                    // Simple HTTP parsing to extract the domain parameter if present
                    var domain = ""
                    let lines = requestStr.components(separatedBy: "\r\n")
                    if let firstLine = lines.first, firstLine.hasPrefix("GET ") {
                        let parts = firstLine.components(separatedBy: " ")
                        if parts.count > 1 {
                            let path = parts[1]
                            if let queryRange = path.range(of: "?domain=") {
                                domain = String(path[queryRange.upperBound...])
                            }
                        }
                    } else if !requestStr.contains("HTTP") {
                        // Fallback in case raw TCP payload is sent directly
                        domain = requestStr.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    var accounts: [[String: String]] = []
                    if let provider = self?.credentialsProvider {
                        accounts = provider(domain)
                    }
                    
                    var shouldAutoFill = false
                    if let pending = self?.pendingAutoFillDomain, !pending.isEmpty, !domain.isEmpty {
                        let cleanPending = pending.lowercased().replacingOccurrences(of: "www.", with: "")
                        let cleanDomain = domain.lowercased().replacingOccurrences(of: "www.", with: "")
                        if cleanDomain.contains(cleanPending) || cleanPending.contains(cleanDomain) {
                            shouldAutoFill = true
                        }
                    }
                    
                    // Consume the auto-fill intent so it only happens exactly once per button press securely
                    if shouldAutoFill {
                        self?.pendingAutoFillDomain = nil
                    }
                    
                    let responseObj: [String: Any] = [
                        "accounts": accounts,
                        "shouldAutoFill": shouldAutoFill
                    ]
                    
                    if let jsonData = try? JSONSerialization.data(withJSONObject: responseObj, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        
                        let httpResponse = """
                        HTTP/1.1 200 OK\r
                        Content-Type: application/json\r
                        Access-Control-Allow-Origin: *\r
                        \r
                        \(jsonString)
                        """
                        
                        connection.send(content: httpResponse.data(using: .utf8), completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    } else {
                        connection.cancel()
                    }
                }
            }
            listener?.start(queue: .main)
            print("Extension server listening on http://127.0.0.1:54321")
        } catch {
            print("Failed to start server: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        print("Extension server stopped")
    }
}
