import Foundation
import CommonCrypto
import CryptoKit

/// Derives encryption keys from the master password using PBKDF2.
enum KeyDerivation {
    /// OWASP-recommended iteration count for PBKDF2-SHA256.
    static let iterations: UInt32 = 600_000
    /// Key length in bytes (256 bits).
    static let keyLength = 32
    /// Salt length in bytes.
    static let saltLength = 32

    /// Generates a cryptographically random salt.
    static func generateSalt() -> Data {
        var salt = Data(count: saltLength)
        salt.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, saltLength, baseAddress)
        }
        return salt
    }

    /// Derives a 256-bit symmetric key from a password and salt using PBKDF2-SHA256.
    static func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Array(password.utf8)
        var derivedKeyBytes = [UInt8](repeating: 0, count: keyLength)

        salt.withUnsafeBytes { saltPtr in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordData,
                passwordData.count,
                saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                iterations,
                &derivedKeyBytes,
                keyLength
            )
        }

        return SymmetricKey(data: Data(derivedKeyBytes))
    }

    /// Creates a verification hash from the derived key using HMAC-SHA256.
    /// This hash is stored and used to verify the master password on unlock.
    static func createVerificationHash(from key: SymmetricKey) -> Data {
        let verificationData = Data("FreePass_MasterKey_Verification".utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: verificationData, using: key)
        return Data(mac)
    }
}
