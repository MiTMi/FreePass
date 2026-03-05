import Foundation
import Security
import LocalAuthentication

/// Manages secure storage of keys, salts, and secrets in the macOS Keychain.
enum KeychainManager {
    private static let service = "com.freepass.app.dev"

    enum KeychainKey: String {
        case salt = "master_salt"
        case verificationHash = "verification_hash"
        case biometricKey = "biometric_derived_key"
    }

    // MARK: - Standard Keychain Operations

    /// Saves data to the Keychain for a given key.
    static func save(_ data: Data, for key: KeychainKey) throws {
        // Delete any existing item first
        delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Loads data from the Keychain for a given key.
    static func load(for key: KeychainKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Deletes a Keychain item for a given key.
    static func delete(for key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Biometric-Protected Key Storage

    /// Saves the derived key with biometric (Touch ID) access protection.
    /// The key can only be retrieved when the user authenticates with Touch ID.
    static func saveBiometricProtectedKey(_ keyData: Data) throws {
        // Delete existing biometric key
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
