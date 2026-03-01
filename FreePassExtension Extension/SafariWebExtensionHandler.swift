import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        // Unwrap the message sent by background.js 
        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        os_log(.default, "Received message from Safari Extension: %@", String(describing: message))

        var responsePayload: [String: Any] = [:]
        
        if let dict = message as? [String: Any], 
           let command = dict["command"] as? String, 
           command == "fetch_credentials",
           let domain = dict["domain"] as? String {
            
            // =========================================================================
            // NOTE TO DEVELOPER: 
            // In a real production app, this Extension runs in a SEPARATE sandboxed process.
            // To fetch the actual user's passwords here:
            // 1. You must add both the App & Extension to an "App Group" (e.g., group.com.freepass.app)
            // 2. You must initialize your SwiftData `ModelContainer` using the shared container URL.
            // 3. You fetch the passwords matching `domain`.
            // For this demo, we are returning a simulated mock vault item tailored to the domain visited!
            // =========================================================================
            
            let mockAccounts = [
                [
                    "title": "My \(domain) Account",
                    "username": "demo_user@\(domain.replacingOccurrences(of: "www.", with: ""))",
                    "password": "SuperSecretPassword123!"
                ]
            ]
            responsePayload["accounts"] = mockAccounts
        }

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [ SFExtensionMessageKey: responsePayload ]
        } else {
            response.userInfo = [ "message": responsePayload ]
        }

        context.completeRequest(returningItems: [ response ], completionHandler: nil)
    }

}
