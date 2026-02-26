import Foundation
import CryptoKit

/// Handles AES-256-GCM encryption and decryption of sensitive vault data.
enum CryptoManager {

    /// Encrypts a plain text string using AES-256-GCM.
    /// Returns the combined sealed box data (nonce + ciphertext + tag).
    static func encrypt(_ plainText: String, using key: SymmetricKey) throws -> Data {
        let data = Data(plainText.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    /// Decrypts AES-256-GCM combined data back to a plain text string.
    static func decrypt(_ combinedData: Data, using key: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let plainText = String(data: decryptedData, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        return plainText
    }
}

enum CryptoError: LocalizedError {
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Failed to encrypt data."
        case .decryptionFailed: return "Failed to decrypt data."
        }
    }
}
