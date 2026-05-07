import SafariServices
import Security
import os.log

/// Bridges the JS background page and the FreePass app's local IPC server.
/// Its sole responsibility is to surface the shared bearer token (provisioned
/// by the main app and stored in the shared keychain access group) to
/// `background.js`. The background page then includes that token as a Bearer
/// header on every request to `http://127.0.0.1:54321`.
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private static let service = "com.freepass.app"
    private static let account = "ipc_bearer_token"
    private static let accessGroup = "$(AppIdentifierPrefix)com.freepass.app"

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        var responsePayload: [String: Any] = [:]

        if let dict = message as? [String: Any], let command = dict["command"] as? String {
            switch command {
            case "get_token":
                if let token = readToken() {
                    responsePayload["token"] = token.base64EncodedString()
                } else {
                    responsePayload["error"] = "FreePass app has not been launched yet."
                }
            default:
                responsePayload["error"] = "Unknown command: \(command)"
            }
        }

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: responsePayload]
        } else {
            response.userInfo = ["message": responsePayload]
        }

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func readToken() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SafariWebExtensionHandler.service,
            kSecAttrAccount as String: SafariWebExtensionHandler.account,
            kSecAttrAccessGroup as String: SafariWebExtensionHandler.accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            os_log(.error, "FreePass extension: failed to read IPC token (status %d)", status)
            return nil
        }
        return result as? Data
    }
}
