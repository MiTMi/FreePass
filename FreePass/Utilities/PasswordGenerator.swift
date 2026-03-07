import Foundation
import Security

/// Generates cryptographically strong random passwords.
struct PasswordGenerator {
    var length: Int
    var includeUppercase: Bool
    var includeLowercase: Bool
    var includeDigits: Bool
    var includeSymbols: Bool

    init() {
        self.length = UserDefaults.standard.object(forKey: "defaultPasswordLength") != nil ? UserDefaults.standard.integer(forKey: "defaultPasswordLength") : 20
        self.includeUppercase = UserDefaults.standard.object(forKey: "defaultPasswordUppercase") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordUppercase") : true
        self.includeLowercase = UserDefaults.standard.object(forKey: "defaultPasswordLowercase") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordLowercase") : true
        self.includeDigits = UserDefaults.standard.object(forKey: "defaultPasswordDigits") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordDigits") : true
        self.includeSymbols = UserDefaults.standard.object(forKey: "defaultPasswordSymbols") != nil ? UserDefaults.standard.bool(forKey: "defaultPasswordSymbols") : true
    }

    private static let uppercaseChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let lowercaseChars = "abcdefghijklmnopqrstuvwxyz"
    private static let digitChars = "0123456789"
    private static let symbolChars = "!@#$%^&*()-_=+[]{}|;:,.<>?"

    /// Generates a random password using `SecRandomCopyBytes`.
    func generate() -> String {
        var characterPool = ""
        if includeUppercase { characterPool += Self.uppercaseChars }
        if includeLowercase { characterPool += Self.lowercaseChars }
        if includeDigits { characterPool += Self.digitChars }
        if includeSymbols { characterPool += Self.symbolChars }

        guard !characterPool.isEmpty else { return "" }

        let poolArray = Array(characterPool)
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)

        let password = randomBytes.map { byte in
            poolArray[Int(byte) % poolArray.count]
        }

        return String(password)
    }

    /// Evaluates the strength of a given password.
    static func evaluateStrength(_ password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .veryWeak }

        var score = 0

        // Length scoring
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        if password.count >= 24 { score += 1 }

        // Character variety scoring
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: symbolChars)) != nil { score += 1 }

        switch score {
        case 0...2: return .veryWeak
        case 3...4: return .weak
        case 5...6: return .fair
        case 7: return .strong
        default: return .veryStrong
        }
    }
}

enum PasswordStrength: Int, CaseIterable {
    case veryWeak = 0
    case weak = 1
    case fair = 2
    case strong = 3
    case veryStrong = 4

    var label: String {
        switch self {
        case .veryWeak: return "Very Weak"
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .strong: return "Strong"
        case .veryStrong: return "Very Strong"
        }
    }

    var fraction: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
    }
}
