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
        .ignoresSafeArea()
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
            guard let key = appState.derivedKey else { return [] }

            var results: [[String: String]] = []
            do {
                let items = try modelContext.fetch(FetchDescriptor<VaultItem>())
                for item in items where !item.isTrashed && !item.isArchived {
                    guard !item.url.isEmpty,
                          DomainMatcher.matches(stored: item.url, requested: domain) else { continue }
                    if let pwd = item.decryptedPassword(using: key) {
                        results.append([
                            "title": item.title,
                            "username": item.username,
                            "password": pwd
                        ])
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

// MARK: - Domain Matching

/// Hostname-suffix domain matching for autofill. Stored entries are matched
/// against the requested domain only when they reference the same host or a
/// parent domain — never a substring/suffix that crosses registrable
/// boundaries. Without a public-suffix list we rely on labelled-suffix logic,
/// which still rejects the obvious confusion attacks (`evil-paypal.com.x` vs.
/// `paypal.com`).
enum DomainMatcher {
    static func matches(stored: String, requested: String) -> Bool {
        guard let storedHost = canonicalHost(from: stored),
              let requestedHost = canonicalHost(from: requested),
              !storedHost.isEmpty, !requestedHost.isEmpty else {
            return false
        }
        if storedHost == requestedHost { return true }
        // The stored entry is a parent of the requested host
        // (e.g. stored `google.com`, visiting `mail.google.com`).
        return requestedHost.hasSuffix("." + storedHost)
    }

    private static func canonicalHost(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var host = URLComponents(string: withScheme)?.host?.lowercased() else {
            // Fall back to treating the input as a bare hostname.
            return strippingWWW(trimmed.lowercased())
        }
        host = strippingWWW(host)
        return host.isEmpty ? nil : host
    }

    private static func strippingWWW(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - Extension IPC Server

final class ExtensionServer: @unchecked Sendable {
    static let shared = ExtensionServer()
    private var listener: NWListener?

    /// Cached bearer token bytes, fetched lazily from the shared keychain.
    private var tokenCache: Data?

    /// A callback to fetch credentials dynamically, provided by AppState.
    var credentialsProvider: ((String) -> [[String: String]])?

    /// The domain the user just clicked "Open & Fill" for in the native app.
    var pendingAutoFillDomain: String?

    /// Provisions the IPC token on demand. Idempotent.
    func ensureToken() -> Data? {
        if let cached = tokenCache { return cached }
        let token = try? KeychainManager.ensureIPCToken()
        tokenCache = token
        return token
    }

    /// Replaces the cached bearer token. Call after `KeychainManager.rotateIPCToken()`
    /// so the next request authorizes against the fresh value. The extension's
    /// JS will hit a 401 on its next call, refresh from the handler, and retry.
    func updateTokenCache(_ token: Data?) {
        tokenCache = token
    }

    func start() {
        do {
            guard ensureToken() != nil else {
                print("ExtensionServer: failed to provision IPC token; refusing to start.")
                return
            }

            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: 54321)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
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

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        guard isLoopback(connection.endpoint) else {
            connection.cancel()
            return
        }
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self else { connection.cancel(); return }
            guard let data, let raw = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            self.respond(to: raw, on: connection)
        }
    }

    /// Validates that the peer is the loopback interface. NWListener accepts
    /// connections on every available interface by default, so this is the
    /// only thing keeping a remote attacker on the same network from speaking
    /// to the credentials endpoint.
    private func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        switch host {
        case .ipv4(let v4):
            return v4.isLoopback
        case .ipv6(let v6):
            return v6.isLoopback
        case .name(let name, _):
            return name == "localhost"
        @unknown default:
            return false
        }
    }

    private func respond(to raw: String, on connection: NWConnection) {
        let request = HTTPRequest.parse(raw)

        // Authorize: constant-time bearer-token comparison.
        guard let presented = request.bearerToken,
              let expected = ensureToken(),
              constantTimeEqual(presented, expected) else {
            send(status: 401, body: "Unauthorized", contentType: "text/plain", on: connection)
            return
        }

        let domain = request.queryValue(for: "domain") ?? ""
        var accounts: [[String: String]] = []
        if let provider = credentialsProvider {
            accounts = provider(domain)
        }

        var shouldAutoFill = false
        if let pending = pendingAutoFillDomain, !pending.isEmpty, !domain.isEmpty,
           DomainMatcher.matches(stored: pending, requested: domain) {
            shouldAutoFill = true
            pendingAutoFillDomain = nil
        }

        let payload: [String: Any] = [
            "accounts": accounts,
            "shouldAutoFill": shouldAutoFill
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            send(status: 500, body: "encode error", contentType: "text/plain", on: connection)
            return
        }
        send(status: 200, body: body, contentType: "application/json", on: connection)
    }

    private func send(status: Int, body: String, contentType: String, on connection: NWConnection) {
        send(status: status, body: Data(body.utf8), contentType: contentType, on: connection)
    }

    private func send(status: Int, body: Data, contentType: String, on connection: NWConnection) {
        let reason: String = {
            switch status {
            case 200: return "OK"
            case 401: return "Unauthorized"
            case 500: return "Internal Server Error"
            default:  return ""
            }
        }()
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "X-Content-Type-Options: nosniff\r\n"
        head += "\r\n"

        var packet = Data(head.utf8)
        packet.append(body)
        connection.send(content: packet, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }
}

// MARK: - Tiny HTTP request parser

private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]

    var bearerToken: Data? {
        guard let value = headers["authorization"] else { return nil }
        let parts = value.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0].lowercased() == "bearer" else { return nil }
        return Data(base64Encoded: String(parts[1]))
    }

    func queryValue(for name: String) -> String? {
        guard let queryStart = path.firstIndex(of: "?") else { return nil }
        let query = path[path.index(after: queryStart)...]
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2, kv[0] == name else { continue }
            return String(kv[1]).removingPercentEncoding ?? String(kv[1])
        }
        return nil
    }

    static func parse(_ raw: String) -> HTTPRequest {
        let lines = raw.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            return HTTPRequest(method: "", path: "", headers: [:])
        }
        let parts = firstLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        let method = parts.count > 0 ? String(parts[0]) : ""
        let path = parts.count > 1 ? String(parts[1]) : ""

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        return HTTPRequest(method: method, path: path, headers: headers)
    }
}
