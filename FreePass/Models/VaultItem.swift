import Foundation
import SwiftData
import CryptoKit

// MARK: - CategoryFieldSpec

/// Describes a single editable field for a vault category.
struct CategoryFieldSpec: Identifiable {
    let id: String          // storage key in encrypted JSON
    let label: String
    let placeholder: String
    var isSecure: Bool = false
    var isMultiline: Bool = false
    var sfSymbol: String = "doc.text"
}

// MARK: - Category field definitions

extension VaultCategory {

    /// The field specs that define what extra fields this category stores in `encryptedFields`.
    /// Login and Credit Card are handled separately via legacy columns; return [] for them.
    var fieldSpecs: [CategoryFieldSpec] {
        switch self {

        case .login, .all, .favorites:
            return []   // handled by dedicated columns

        case .secureNote:
            return []   // just title + notes

        case .creditCard:
            return [
                CategoryFieldSpec(id: "cardholderName", label: "Cardholder Name", placeholder: "e.g. John Smith", sfSymbol: "person"),
                CategoryFieldSpec(id: "bank", label: "Bank / Issuer", placeholder: "e.g. Chase", sfSymbol: "building.columns"),
                CategoryFieldSpec(id: "cardType", label: "Card Type", placeholder: "e.g. Visa, Mastercard", sfSymbol: "creditcard"),
            ]

        case .identity:
            return [
                CategoryFieldSpec(id: "firstName", label: "First Name", placeholder: "e.g. John", sfSymbol: "person"),
                CategoryFieldSpec(id: "lastName", label: "Last Name", placeholder: "e.g. Smith", sfSymbol: "person"),
                CategoryFieldSpec(id: "email", label: "Email", placeholder: "e.g. john@example.com", sfSymbol: "envelope"),
                CategoryFieldSpec(id: "phone", label: "Phone", placeholder: "e.g. +1 555 000 1234", sfSymbol: "phone"),
                CategoryFieldSpec(id: "dob", label: "Date of Birth", placeholder: "e.g. 01/01/1990", sfSymbol: "calendar"),
                CategoryFieldSpec(id: "address", label: "Address", placeholder: "e.g. 123 Main St", sfSymbol: "house"),
                CategoryFieldSpec(id: "city", label: "City", placeholder: "e.g. New York", sfSymbol: "map"),
                CategoryFieldSpec(id: "state", label: "State / Province", placeholder: "e.g. NY", sfSymbol: "map"),
                CategoryFieldSpec(id: "country", label: "Country", placeholder: "e.g. United States", sfSymbol: "globe"),
                CategoryFieldSpec(id: "company", label: "Company", placeholder: "e.g. Acme Corp", sfSymbol: "building.2"),
            ]

        case .password:
            return [
                CategoryFieldSpec(id: "username", label: "Username / Email", placeholder: "e.g. user@example.com", sfSymbol: "person"),
                CategoryFieldSpec(id: "password", label: "Password", placeholder: "••••••••", isSecure: true, sfSymbol: "key.horizontal"),
            ]

        case .document:
            return [
                CategoryFieldSpec(id: "filename", label: "File Name", placeholder: "e.g. contract.pdf", sfSymbol: "doc"),
                CategoryFieldSpec(id: "description", label: "Description", placeholder: "What this document is about", isMultiline: true, sfSymbol: "text.alignleft"),
            ]

        case .sshKey:
            return [
                CategoryFieldSpec(id: "host", label: "Host / Server", placeholder: "e.g. github.com", sfSymbol: "network"),
                CategoryFieldSpec(id: "port", label: "Port", placeholder: "e.g. 22", sfSymbol: "number"),
                CategoryFieldSpec(id: "username", label: "Username", placeholder: "e.g. git", sfSymbol: "person"),
                CategoryFieldSpec(id: "keyType", label: "Key Type", placeholder: "e.g. ed25519, RSA", sfSymbol: "key.horizontal"),
                CategoryFieldSpec(id: "publicKey", label: "Public Key", placeholder: "ssh-ed25519 AAAA...", isMultiline: true, sfSymbol: "key"),
                CategoryFieldSpec(id: "privateKey", label: "Private Key", placeholder: "-----BEGIN OPENSSH PRIVATE KEY-----", isSecure: true, isMultiline: true, sfSymbol: "lock"),
                CategoryFieldSpec(id: "passphrase", label: "Passphrase", placeholder: "Key passphrase (if any)", isSecure: true, sfSymbol: "lock.shield"),
            ]

        case .apiCredentials:
            return [
                CategoryFieldSpec(id: "username", label: "Username / Account", placeholder: "e.g. your username", sfSymbol: "person"),
                CategoryFieldSpec(id: "apiKey", label: "API Key", placeholder: "••••••••••••••••", isSecure: true, sfSymbol: "key.horizontal"),
                CategoryFieldSpec(id: "apiSecret", label: "API Secret", placeholder: "••••••••••••••••", isSecure: true, sfSymbol: "lock"),
                CategoryFieldSpec(id: "endpoint", label: "Endpoint / Base URL", placeholder: "e.g. https://api.example.com", sfSymbol: "network"),
            ]

        case .bankAccount:
            return [
                CategoryFieldSpec(id: "bankName", label: "Bank Name", placeholder: "e.g. Chase", sfSymbol: "building.columns"),
                CategoryFieldSpec(id: "accountType", label: "Account Type", placeholder: "e.g. Checking, Savings", sfSymbol: "banknote"),
                CategoryFieldSpec(id: "accountNumber", label: "Account Number", placeholder: "••••••••••••", isSecure: true, sfSymbol: "number"),
                CategoryFieldSpec(id: "routingNumber", label: "Routing Number", placeholder: "••••••••••••", isSecure: true, sfSymbol: "arrow.left.arrow.right"),
                CategoryFieldSpec(id: "swift", label: "SWIFT / BIC", placeholder: "e.g. CHASUS33", sfSymbol: "globe"),
                CategoryFieldSpec(id: "iban", label: "IBAN", placeholder: "e.g. GB29 NWBK …", isSecure: true, sfSymbol: "creditcard"),
            ]

        case .cryptoWallet:
            return [
                CategoryFieldSpec(id: "network", label: "Network", placeholder: "e.g. Ethereum, Bitcoin", sfSymbol: "network"),
                CategoryFieldSpec(id: "walletAddress", label: "Wallet Address", placeholder: "0x…", isSecure: true, sfSymbol: "bitcoinsign.circle"),
                CategoryFieldSpec(id: "seedPhrase", label: "Seed Phrase", placeholder: "word1 word2 … word24", isSecure: true, isMultiline: true, sfSymbol: "lock.doc"),
            ]

        case .database:
            return [
                CategoryFieldSpec(id: "host", label: "Host", placeholder: "e.g. db.example.com", sfSymbol: "network"),
                CategoryFieldSpec(id: "port", label: "Port", placeholder: "e.g. 5432", sfSymbol: "number"),
                CategoryFieldSpec(id: "databaseName", label: "Database Name", placeholder: "e.g. my_database", sfSymbol: "cylinder"),
                CategoryFieldSpec(id: "dbType", label: "Type", placeholder: "e.g. PostgreSQL, MySQL", sfSymbol: "cylinder.split.1x2"),
                CategoryFieldSpec(id: "username", label: "Username", placeholder: "e.g. admin", sfSymbol: "person"),
                CategoryFieldSpec(id: "password", label: "Password", placeholder: "••••••••", isSecure: true, sfSymbol: "lock"),
            ]

        case .driverLicense:
            return [
                CategoryFieldSpec(id: "fullName", label: "Full Name", placeholder: "e.g. John Smith", sfSymbol: "person"),
                CategoryFieldSpec(id: "licenseNumber", label: "License Number", placeholder: "e.g. D1234567", isSecure: true, sfSymbol: "number"),
                CategoryFieldSpec(id: "licenseClass", label: "Class", placeholder: "e.g. B, C, D", sfSymbol: "list.bullet"),
                CategoryFieldSpec(id: "state", label: "State / Province", placeholder: "e.g. California", sfSymbol: "map"),
                CategoryFieldSpec(id: "country", label: "Country", placeholder: "e.g. United States", sfSymbol: "globe"),
                CategoryFieldSpec(id: "dob", label: "Date of Birth", placeholder: "e.g. 01/01/1990", sfSymbol: "calendar"),
                CategoryFieldSpec(id: "expiry", label: "Expiry Date", placeholder: "e.g. 12/2028", sfSymbol: "calendar.badge.exclamationmark"),
            ]

        case .email:
            return [
                CategoryFieldSpec(id: "emailAddress", label: "Email Address", placeholder: "e.g. user@example.com", sfSymbol: "envelope"),
                CategoryFieldSpec(id: "password", label: "Password", placeholder: "••••••••", isSecure: true, sfSymbol: "lock"),
                CategoryFieldSpec(id: "host", label: "Mail Server (IMAP)", placeholder: "e.g. imap.gmail.com", sfSymbol: "network"),
                CategoryFieldSpec(id: "imapPort", label: "IMAP Port", placeholder: "e.g. 993", sfSymbol: "number"),
                CategoryFieldSpec(id: "smtpHost", label: "SMTP Server", placeholder: "e.g. smtp.gmail.com", sfSymbol: "network"),
                CategoryFieldSpec(id: "smtpPort", label: "SMTP Port", placeholder: "e.g. 587", sfSymbol: "number"),
            ]

        case .medicalRecord:
            return [
                CategoryFieldSpec(id: "provider", label: "Provider / Doctor", placeholder: "e.g. Dr. Smith", sfSymbol: "stethoscope"),
                CategoryFieldSpec(id: "conditions", label: "Conditions / Diagnoses", placeholder: "e.g. Hypertension", isMultiline: true, sfSymbol: "cross.case"),
                CategoryFieldSpec(id: "medications", label: "Medications", placeholder: "e.g. Lisinopril 10mg", isMultiline: true, sfSymbol: "pills"),
                CategoryFieldSpec(id: "lastVisit", label: "Last Visit", placeholder: "e.g. 01/03/2025", sfSymbol: "calendar"),
            ]

        case .membership:
            return [
                CategoryFieldSpec(id: "organization", label: "Organization", placeholder: "e.g. Costco", sfSymbol: "building"),
                CategoryFieldSpec(id: "memberId", label: "Member ID", placeholder: "e.g. 123456789", isSecure: true, sfSymbol: "number"),
                CategoryFieldSpec(id: "memberSince", label: "Member Since", placeholder: "e.g. 01/2020", sfSymbol: "calendar"),
                CategoryFieldSpec(id: "expiry", label: "Expiry Date", placeholder: "e.g. 12/2026", sfSymbol: "calendar.badge.exclamationmark"),
                CategoryFieldSpec(id: "website", label: "Website", placeholder: "e.g. https://costco.com", sfSymbol: "globe"),
            ]

        case .outdoorLicense:
            return [
                CategoryFieldSpec(id: "licenseNumber", label: "License Number", placeholder: "e.g. OL-12345", isSecure: true, sfSymbol: "number"),
                CategoryFieldSpec(id: "licenseType", label: "License Type", placeholder: "e.g. Fishing, Hunting", sfSymbol: "list.bullet"),
                CategoryFieldSpec(id: "state", label: "State / Province", placeholder: "e.g. Montana", sfSymbol: "map"),
                CategoryFieldSpec(id: "country", label: "Country", placeholder: "e.g. United States", sfSymbol: "globe"),
                CategoryFieldSpec(id: "expiry", label: "Expiry Date", placeholder: "e.g. 12/2025", sfSymbol: "calendar.badge.exclamationmark"),
            ]

        case .passport:
            return [
                CategoryFieldSpec(id: "fullName", label: "Full Name", placeholder: "e.g. John Smith", sfSymbol: "person"),
                CategoryFieldSpec(id: "passportNumber", label: "Passport Number", placeholder: "e.g. A12345678", isSecure: true, sfSymbol: "number"),
                CategoryFieldSpec(id: "nationality", label: "Nationality", placeholder: "e.g. American", sfSymbol: "globe"),
                CategoryFieldSpec(id: "issuingCountry", label: "Issuing Country", placeholder: "e.g. United States", sfSymbol: "flag"),
                CategoryFieldSpec(id: "issueDate", label: "Issue Date", placeholder: "e.g. 01/2019", sfSymbol: "calendar"),
                CategoryFieldSpec(id: "expiry", label: "Expiry Date", placeholder: "e.g. 01/2029", sfSymbol: "calendar.badge.exclamationmark"),
                CategoryFieldSpec(id: "dob", label: "Date of Birth", placeholder: "e.g. 01/01/1990", sfSymbol: "calendar"),
            ]

        case .rewards:
            return [
                CategoryFieldSpec(id: "company", label: "Company / Program", placeholder: "e.g. Delta SkyMiles", sfSymbol: "building"),
                CategoryFieldSpec(id: "memberId", label: "Member ID / Number", placeholder: "e.g. 1234567890", isSecure: true, sfSymbol: "number"),
                CategoryFieldSpec(id: "memberSince", label: "Member Since", placeholder: "e.g. 01/2020", sfSymbol: "calendar"),
                CategoryFieldSpec(id: "pin", label: "PIN", placeholder: "••••", isSecure: true, sfSymbol: "lock"),
            ]

        case .server:
            return [
                CategoryFieldSpec(id: "hostname", label: "Hostname / IP", placeholder: "e.g. 192.168.1.1", sfSymbol: "network"),
                CategoryFieldSpec(id: "port", label: "Port", placeholder: "e.g. 22, 80, 443", sfSymbol: "number"),
                CategoryFieldSpec(id: "serverType", label: "Server Type", placeholder: "e.g. Ubuntu, nginx, Apache", sfSymbol: "server.rack"),
                CategoryFieldSpec(id: "username", label: "Username", placeholder: "e.g. root", sfSymbol: "person"),
                CategoryFieldSpec(id: "password", label: "Password", placeholder: "••••••••", isSecure: true, sfSymbol: "lock"),
                CategoryFieldSpec(id: "publicIp", label: "Public IP", placeholder: "e.g. 54.12.34.56", sfSymbol: "globe"),
            ]

        case .socialSecurityNumber:
            return [
                CategoryFieldSpec(id: "fullName", label: "Full Name", placeholder: "e.g. John Smith", sfSymbol: "person"),
                CategoryFieldSpec(id: "ssn", label: "Social Security Number", placeholder: "e.g. XXX-XX-XXXX", isSecure: true, sfSymbol: "number"),
                CategoryFieldSpec(id: "dob", label: "Date of Birth", placeholder: "e.g. 01/01/1990", sfSymbol: "calendar"),
            ]

        case .softwareLicense:
            return [
                CategoryFieldSpec(id: "product", label: "Product Name", placeholder: "e.g. Adobe Photoshop", sfSymbol: "app"),
                CategoryFieldSpec(id: "version", label: "Version", placeholder: "e.g. 25.0", sfSymbol: "number"),
                CategoryFieldSpec(id: "licenseKey", label: "License Key", placeholder: "XXXX-XXXX-XXXX-XXXX", isSecure: true, sfSymbol: "key.horizontal"),
                CategoryFieldSpec(id: "email", label: "Registered Email", placeholder: "e.g. user@example.com", sfSymbol: "envelope"),
                CategoryFieldSpec(id: "registeredTo", label: "Registered To", placeholder: "e.g. John Smith", sfSymbol: "person"),
                CategoryFieldSpec(id: "purchaseDate", label: "Purchase Date", placeholder: "e.g. 03/2024", sfSymbol: "calendar"),
                CategoryFieldSpec(id: "expiry", label: "Expiry / Renewal", placeholder: "e.g. 03/2025", sfSymbol: "calendar.badge.exclamationmark"),
            ]

        case .wirelessRouter:
            return [
                CategoryFieldSpec(id: "networkName", label: "Network Name (SSID)", placeholder: "e.g. MyHomeWifi", sfSymbol: "wifi"),
                CategoryFieldSpec(id: "password", label: "Wi-Fi Password", placeholder: "••••••••", isSecure: true, sfSymbol: "lock"),
                CategoryFieldSpec(id: "routerModel", label: "Router Model", placeholder: "e.g. Asus RT-AX88U", sfSymbol: "wifi.router"),
                CategoryFieldSpec(id: "ipAddress", label: "Router IP", placeholder: "e.g. 192.168.1.1", sfSymbol: "network"),
                CategoryFieldSpec(id: "macAddress", label: "MAC Address", placeholder: "e.g. AA:BB:CC:DD:EE:FF", sfSymbol: "number"),
            ]
        }
    }

    /// The field key whose value is displayed as the list subtitle for this category.
    var subtitleFieldKey: String? {
        switch self {
        case .login:                return nil  // uses item.username directly
        case .creditCard:           return nil  // uses item.username directly
        case .identity:             return "email"
        case .password:             return "username"
        case .document:             return "filename"
        case .sshKey:               return "host"
        case .apiCredentials:       return "endpoint"
        case .bankAccount:          return "bankName"
        case .cryptoWallet:         return "network"
        case .database:             return "host"
        case .driverLicense:        return "licenseNumber"
        case .email:                return "emailAddress"
        case .medicalRecord:        return "provider"
        case .membership:           return "organization"
        case .outdoorLicense:       return "licenseNumber"
        case .passport:             return "passportNumber"
        case .rewards:              return "company"
        case .server:               return "hostname"
        case .socialSecurityNumber: return "fullName"
        case .softwareLicense:      return "product"
        case .wirelessRouter:       return "networkName"
        default:                    return nil
        }
    }
}

// MARK: - VaultItem Model

/// A single item stored in the password vault.
@Model
final class VaultItem {
    var id: UUID
    var title: String
    /// Primary identifier / subtitle shown in the list. Meaning varies by category.
    var username: String
    /// AES-256-GCM combined data (nonce + ciphertext + tag) for the password. Login only.
    var encryptedPassword: Data
    var url: String
    /// AES-256-GCM combined data for notes (optional, all categories).
    var encryptedNotes: Data?
    // Legacy credit card columns (kept for backward compatibility)
    var encryptedCardNumber: Data?
    var encryptedCardExpiration: Data?
    var encryptedCardCVV: Data?
    /// Encrypted JSON dictionary `[String: String]` for all category-specific fields.
    var encryptedFields: Data?
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
        encryptedFields: Data? = nil,
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
        self.encryptedFields = encryptedFields
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

    /// Decrypts the generic field dictionary for non-Login/CreditCard categories.
    func decryptedFields(using key: SymmetricKey) -> [String: String]? {
        guard let encryptedFields else { return nil }
        guard let json = try? CryptoManager.decrypt(encryptedFields, using: key),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// Encrypts a `[String: String]` dictionary into Data for `encryptedFields`.
    static func encryptFields(_ values: [String: String], using key: SymmetricKey) throws -> Data {
        let data = try JSONEncoder().encode(values)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return try CryptoManager.encrypt(json, using: key)
    }
}

// MARK: - Vault Category (enum only – styling in CategoryIcon.swift)

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

    static var mainCategories: [VaultCategory] {
        [.login, .secureNote, .creditCard, .identity, .password, .document]
    }

    static var otherCategories: [VaultCategory] {
        [.sshKey, .apiCredentials, .bankAccount, .cryptoWallet, .database, .driverLicense,
         .email, .medicalRecord, .membership, .outdoorLicense, .passport, .rewards,
         .server, .socialSecurityNumber, .softwareLicense, .wirelessRouter]
    }

    static var itemCategories: [VaultCategory] {
        mainCategories + otherCategories
    }
}
