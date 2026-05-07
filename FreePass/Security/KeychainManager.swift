import Foundation
import Security
import LocalAuthentication

/// Manages secure storage of keys, salts, and secrets in the macOS Keychain.
enum KeychainManager {
    /// Production service identifier. Items written here are visible to both
    /// the main app and the Safari extension (when both list the access group).
    private static let service = "com.freepass.app"

    /// Legacy service used by early dev builds. Read-only — used for one-shot
    /// migration so existing vaults don't get locked out by the rename.
    private static let legacyService = "com.freepass.app.dev"

    /// Shared keychain access group. Both `FreePass.entitlements` and
    /// `FreePassExtension_Extension.entitlements` declare this group, so the
    /// extension's request handler can read the IPC token without
    /// re-derivation or App Group file plumbing.
    static let sharedAccessGroup = "$(AppIdentifierPrefix)com.freepass.app"

    enum KeychainKey: String {
        case salt = "master_salt"
        case verificationHash = "verification_hash"
        case biometricKey = "biometric_derived_key"
        /// Random 32-byte secret negotiated between the app and its Safari extension.
        /// Required as a Bearer token on every localhost IPC request.
        case ipcToken = "ipc_bearer_token"
    }

    // MARK: - Standard Keychain Operations

    /// Saves data to the Keychain for a given key.
    /// `inSharedGroup: true` writes the item with the shared access group so the
    /// extension can read it. Use only for non-sensitive IPC plumbing (the token).
    static func save(_ data: Data, for key: KeychainKey, inSharedGroup: Bool = false) throws {
        delete(for: key, inSharedGroup: inSharedGroup)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        if inSharedGroup {
            query[kSecAttrAccessGroup as String] = sharedAccessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Loads data from the Keychain. Falls back to the legacy `.dev` service
    /// for the unlock-critical keys (`salt`, `verificationHash`) so old vaults
    /// remain accessible after the service rename. The migration step writes
    /// the value back under the new service and deletes the legacy entry.
    static func load(for key: KeychainKey, inSharedGroup: Bool = false) -> Data? {
        if let data = read(service: service, account: key.rawValue, accessGroup: inSharedGroup ? sharedAccessGroup : nil) {
            return data
        }

        // One-shot migration from the legacy dev service for vault-bootstrap items.
        guard !inSharedGroup, key == .salt || key == .verificationHash || key == .biometricKey else {
            return nil
        }
        guard let legacy = read(service: legacyService, account: key.rawValue, accessGroup: nil) else {
            return nil
        }
        try? save(legacy, for: key, inSharedGroup: false)
        deleteLegacy(account: key.rawValue)
        return legacy
    }

    /// Deletes a Keychain item for a given key (in the matching scope).
    static func delete(for key: KeychainKey, inSharedGroup: Bool = false) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        if inSharedGroup {
            query[kSecAttrAccessGroup as String] = sharedAccessGroup
        }
        SecItemDelete(query as CFDictionary)
    }

    private static func read(service: String, account: String, accessGroup: String?) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func deleteLegacy(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Biometric-Protected Key Storage

    /// Saves the derived key with biometric (Touch ID) access protection.
    /// The key can only be retrieved when the user authenticates with Touch ID.
    static func saveBiometricProtectedKey(_ keyData: Data) throws {
        delete(for: .biometricKey)

        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw KeychainError.accessControlCreationFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: KeychainKey.biometricKey.rawValue,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: access
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Loads the derived key with biometric authentication.
    /// This triggers the Touch ID prompt automatically.
    static func loadBiometricProtectedKey() throws -> Data {
        let context = LAContext()
        context.localizedReason = "Unlock your FreePass vault"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: KeychainKey.biometricKey.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.loadFailed(errSecItemNotFound)
        }
        return data
    }

    // MARK: - IPC Bearer Token

    /// Returns the existing IPC bearer token, or generates and persists a new
    /// one. The token lives in the shared keychain access group so the Safari
    /// extension's handler can return it to background.js on demand.
    @discardableResult
    static func ensureIPCToken() throws -> Data {
        if let existing = load(for: .ipcToken, inSharedGroup: true) {
            return existing
        }
        return try generateAndStoreIPCToken()
    }

    /// Generates a fresh IPC bearer token, replacing any existing one. Called
    /// after sensitive auth events (unlock, re-key) so the previous token's
    /// usable lifetime is bounded by the user's session, not by the keychain.
    @discardableResult
    static func rotateIPCToken() throws -> Data {
        return try generateAndStoreIPCToken()
    }

    private static func generateAndStoreIPCToken() throws -> Data {
        var token = Data(count: 32)
        let status = token.withUnsafeMutableBytes { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, 32, base)
        }
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
        try save(token, for: .ipcToken, inSharedGroup: true)
        return token
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case accessControlCreationFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))."
        case .loadFailed(let status):
            return "Failed to load from Keychain (status: \(status))."
        case .accessControlCreationFailed:
            return "Failed to create biometric access control."
        }
    }
}
