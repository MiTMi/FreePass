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
    var encryptedCardNumber: Data?
    var encryptedCardExpiration: Data?
    var encryptedCardCVV: Data?
    var category: String
    var isFavorite: Bool
    var isArchived: Bool = false
    var isTrashed: Bool = false
    var trashedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        username: String,
        encryptedPassword: Data,
        url: String = "",
        encryptedNotes: Data? = nil,
        encryptedCardNumber: Data? = nil,
        encryptedCardExpiration: Data? = nil,
        encryptedCardCVV: Data? = nil,
        category: String = "Login",
        isFavorite: Bool = false,
        isArchived: Bool = false,
        isTrashed: Bool = false,
        trashedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.username = username
        self.encryptedPassword = encryptedPassword
        self.url = url
        self.encryptedNotes = encryptedNotes
        self.encryptedCardNumber = encryptedCardNumber
        self.encryptedCardExpiration = encryptedCardExpiration
        self.encryptedCardCVV = encryptedCardCVV
        self.category = category
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isTrashed = isTrashed
        self.trashedAt = trashedAt
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

    func decryptedNotes(using key: SymmetricKey) -> String? {
        guard let encryptedNotes else { return nil }
        return try? CryptoManager.decrypt(encryptedNotes, using: key)
    }

    func decryptedCardNumber(using key: SymmetricKey) -> String? {
        guard let encryptedCardNumber else { return nil }
        return try? CryptoManager.decrypt(encryptedCardNumber, using: key)
    }

    func decryptedCardExpiration(using key: SymmetricKey) -> String? {
        guard let encryptedCardExpiration else { return nil }
        return try? CryptoManager.decrypt(encryptedCardExpiration, using: key)
    }

    func decryptedCardCVV(using key: SymmetricKey) -> String? {
        guard let encryptedCardCVV else { return nil }
        return try? CryptoManager.decrypt(encryptedCardCVV, using: key)
    }
}

// MARK: - Vault Category

enum VaultCategory: String, CaseIterable, Identifiable {
    case all = "All Items"
    case login = "Login"
    case secureNote = "Secure Note"
    case creditCard = "Credit Card"
    case identity = "Identity"
    case password = "Password"
    case document = "Document"
    case sshKey = "SSH Key"
    case apiCredentials = "API Credentials"
    case bankAccount = "Bank Account"
    case cryptoWallet = "Crypto Wallet"
    case database = "Database"
    case driverLicense = "Driver License"
    case email = "Email"
    case medicalRecord = "Medical Record"
    case membership = "Membership"
    case outdoorLicense = "Outdoor License"
    case passport = "Passport"
    case rewards = "Rewards"
    case server = "Server"
    case socialSecurityNumber = "Social Security Number"
    case softwareLicense = "Software License"
    case wirelessRouter = "Wireless Router"
    case favorites = "Favorites"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .login: return "lock.square.fill"
        case .secureNote: return "note.text"
        case .creditCard: return "creditcard.fill"
        case .identity: return "person.text.rectangle.fill"
        case .password: return "key.fill"
        case .document: return "doc.fill"
        case .sshKey: return "terminal.fill"
        case .apiCredentials: return "curlybraces.square.fill"
        case .bankAccount: return "dollarsign.circle.fill"
        case .cryptoWallet: return "lanyardcard.fill"
        case .database: return "cylinder.split.1x2.fill"
        case .driverLicense: return "car.fill"
        case .email: return "envelope.fill"
        case .medicalRecord: return "heart.text.square.fill"
        case .membership: return "star.circle.fill"
        case .outdoorLicense: return "leaf.fill"
        case .passport: return "text.book.closed.fill"
        case .rewards: return "gift.fill"
        case .server: return "server.rack"
        case .socialSecurityNumber: return "shield.fill"
        case .softwareLicense: return "checkmark.seal.fill"
        case .wirelessRouter: return "wifi.router.fill"
        case .favorites: return "star.fill"
        }
    }

    var color: String {
        switch self {
        case .all: return "fpAccentPurple"
        case .login: return "fpAccentBlue"
        case .secureNote: return "fpWarning"
        case .creditCard: return "fpAccentBlue"
        case .identity: return "fpSuccess"
        case .password: return "fpAccentBlue"
        case .document: return "fpAccentPurple"
        case .sshKey: return "fpTextSecondary"
        case .apiCredentials: return "fpAccentBlue"
        case .bankAccount: return "fpWarning"
        case .cryptoWallet: return "fpAccentBlue"
        case .database: return "fpTextSecondary"
        case .driverLicense: return "fpDanger"
        case .email: return "fpDanger"
        case .medicalRecord: return "fpTextPrimary"
        case .membership: return "fpAccentPurple"
        case .outdoorLicense: return "fpSuccess"
        case .passport: return "fpAccentBlue"
        case .rewards: return "fpDanger"
        case .server: return "fpTextSecondary"
        case .socialSecurityNumber: return "fpAccentBlue"
        case .softwareLicense: return "fpAccentBlue"
        case .wirelessRouter: return "fpTextSecondary"
        case .favorites: return "fpWarning"
        }
    }

    static var mainCategories: [VaultCategory] {
        [.login, .secureNote, .creditCard, .identity, .password, .document]
    }

    static var otherCategories: [VaultCategory] {
        [.sshKey, .apiCredentials, .bankAccount, .cryptoWallet, .database, .driverLicense, .email, .medicalRecord, .membership, .outdoorLicense, .passport, .rewards, .server, .socialSecurityNumber, .softwareLicense, .wirelessRouter]
    }

    static var itemCategories: [VaultCategory] {
        mainCategories + otherCategories
    }
}
