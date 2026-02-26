import Foundation
import SwiftData
import CryptoKit

/// A single item stored in the password vault.
@Model
final class VaultItem {
    var id: UUID
    var title: String
    var username: String
    /// AES-256-GCM combined data (nonce + ciphertext + tag) for the password.
    var encryptedPassword: Data
    var url: String
    /// AES-256-GCM combined data for notes (optional).
    var encryptedNotes: Data?
    var category: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        username: String,
        encryptedPassword: Data,
        url: String = "",
        encryptedNotes: Data? = nil,
        category: String = "Login",
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.username = username
        self.encryptedPassword = encryptedPassword
        self.url = url
        self.encryptedNotes = encryptedNotes
        self.category = category
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Decryption Helpers

extension VaultItem {
    /// Decrypts the stored password using the provided key.
    func decryptedPassword(using key: SymmetricKey) -> String? {
        try? CryptoManager.decrypt(encryptedPassword, using: key)
    }

    /// Decrypts the stored notes using the provided key.
    func decryptedNotes(using key: SymmetricKey) -> String? {
        guard let encryptedNotes else { return nil }
        return try? CryptoManager.decrypt(encryptedNotes, using: key)
    }
}

// MARK: - Vault Category

enum VaultCategory: String, CaseIterable, Identifiable {
    case all = "All Items"
    case login = "Login"
    case secureNote = "Secure Note"
    case creditCard = "Credit Card"
    case identity = "Identity"
    case favorites = "Favorites"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .login: return "person.circle.fill"
        case .secureNote: return "note.text"
        case .creditCard: return "creditcard.fill"
        case .identity: return "person.text.rectangle.fill"
        case .favorites: return "star.fill"
        }
    }

    /// Categories that represent actual item types (not virtual groups like "All" or "Favorites")
    static var itemCategories: [VaultCategory] {
        [.login, .secureNote, .creditCard, .identity]
    }
}
