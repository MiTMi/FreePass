import Foundation
import CryptoKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Global application state managing lock/unlock, master password, and inactivity timer.
@Observable
@MainActor
final class AppState {
    var isUnlocked = false
    var isFirstLaunch = true
    var derivedKey: SymmetricKey?
    var touchIDEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "touchIDEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "touchIDEnabled") }
    }
    var errorMessage: String?
    var hasPromptedForTouchIDOnLaunch = false
    private(set) var isLoading = false
    private var inactivityTimer: Timer?
    private var activityMonitor: Any?
    #if os(macOS)
    private var sleepObservers: [NSObjectProtocol] = []
    #endif

    var lockTimeout: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: "lockTimeout") == nil {
                return 300 // Default to 5 minutes
            }
            return UserDefaults.standard.double(forKey: "lockTimeout")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lockTimeout")
            resetInactivityTimer() // Reset immediately when changed
        }
    }

    var lockOnSleep: Bool {
        get {
            if UserDefaults.standard.object(forKey: "lockOnSleep") == nil { return true }
            return UserDefaults.standard.bool(forKey: "lockOnSleep")
        }
        set { UserDefaults.standard.set(newValue, forKey: "lockOnSleep") }
    }

    var clearClipboardDelay: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: "clearClipboardDelay") == nil { return 30 }
            return UserDefaults.standard.double(forKey: "clearClipboardDelay")
        }
        set { UserDefaults.standard.set(newValue, forKey: "clearClipboardDelay") }
    }

    var showMenuBarIcon: Bool {
        get {
            if UserDefaults.standard.object(forKey: "showMenuBarIcon") == nil { return true }
            return UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        }
        set { UserDefaults.standard.set(newValue, forKey: "showMenuBarIcon") }
    }

    init() {
        checkFirstLaunch()

        #if os(macOS)
        let center = NSWorkspace.shared.notificationCenter
        let lockOnEvent: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.lockOnSleep else { return }
                self.lock()
            }
        }
        sleepObservers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main, using: lockOnEvent))
        sleepObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: lockOnEvent))
        #endif
    }
    // No deinit: AppState is owned by @main as a singleton-for-lifetime, and a
    // @MainActor class can't reach its main-isolated state from deinit anyway.

    /// Checks if a vault has been set up before.
    func checkFirstLaunch() {
        let salt = KeychainManager.load(for: .salt)
        isFirstLaunch = (salt == nil)
    }

    // MARK: - Master Password Setup

    /// Creates a new vault with the given master password.
    func setupMasterPassword(_ password: String, enableTouchID: Bool) throws {
        isLoading = true
        defer { isLoading = false }

        let salt = KeyDerivation.generateSalt()
        let key = KeyDerivation.deriveKey(from: password, salt: salt)
        let verificationHash = KeyDerivation.createVerificationHash(from: key)

        do {
            try KeychainManager.save(salt, for: .salt)
            try KeychainManager.save(verificationHash, for: .verificationHash)

            var touchIDSucceeded = false
            if enableTouchID {
                do {
                    let keyData = key.withUnsafeBytes { Data($0) }
                    try KeychainManager.saveBiometricProtectedKey(keyData)
                    touchIDSucceeded = true
                } catch {
                    print("Could not enable Touch ID (often due to local sandbox entitlement constraints): \(error)")
                    // We do not throw here, so the vault is still successfully created,
                    // just without Touch ID capabilities.
                }
            }

            self.derivedKey = key
            self.touchIDEnabled = touchIDSucceeded
            self.isFirstLaunch = false
            self.isUnlocked = true
            self.errorMessage = nil
            startActivityTracking()
            resetInactivityTimer()
            rotateExtensionTokenAfterAuth()
        } catch {
            // Clean up partial state if anything fails
            KeychainManager.delete(for: .salt)
            KeychainManager.delete(for: .verificationHash)
            throw error
        }
    }

    // MARK: - Unlock

    /// Attempts to unlock the vault with the given master password.
    @discardableResult
    func unlock(with password: String) -> Bool {
        isLoading = true
        defer { isLoading = false }

        guard let salt = KeychainManager.load(for: .salt),
              let storedHash = KeychainManager.load(for: .verificationHash) else {
            errorMessage = "Vault data not found. Please set up again."
            return false
        }

        let key = KeyDerivation.deriveKey(from: password, salt: salt)
        let verificationHash = KeyDerivation.createVerificationHash(from: key)

        if constantTimeEqual(verificationHash, storedHash) {
            // Self-healing: Automatically enable and save Touch ID on successful password
            // unlock if the device supports it, repairing any broken keychain state.
            if BiometricAuth.isAvailable {
                do {
                    let keyData = key.withUnsafeBytes { Data($0) }
                    try KeychainManager.saveBiometricProtectedKey(keyData)
                    self.touchIDEnabled = true
                } catch {
                    print("Auto-enable Touch ID failed: \(error)")
                }
            }

            self.derivedKey = key
            self.isUnlocked = true
            self.errorMessage = nil
            startActivityTracking()
            resetInactivityTimer()
            rotateExtensionTokenAfterAuth()
            return true
        }

        errorMessage = "Incorrect master password."
        return false
    }

    /// Attempts to unlock the vault using Touch ID.
    func unlockWithBiometrics() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let keyData = try KeychainManager.loadBiometricProtectedKey()
                    Task { @MainActor in
                        self.derivedKey = SymmetricKey(data: keyData)
                        self.isUnlocked = true
                        self.errorMessage = nil
                        self.startActivityTracking()
                        self.resetInactivityTimer()
                        self.rotateExtensionTokenAfterAuth()
                        continuation.resume(returning: true)
                    }
                } catch {
                    Task { @MainActor in
                        if let keychainErr = error as? KeychainError, case .loadFailed(let status) = keychainErr {
                            if status == errSecUserCanceled {
                                self.errorMessage = nil
                            } else if status == errSecItemNotFound {
                                // Sometimes macOS returns errSecItemNotFound if the user cancels.
                                // Do NOT disable the TouchID flag here — that permanently hides the button.
                                self.errorMessage = nil
                            } else {
                                self.errorMessage = "Touch ID authentication failed (status: \(status))."
                            }
                        } else {
                            self.errorMessage = "Touch ID authentication failed."
                        }
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    // MARK: - Change Master Password

    /// Re-keys the entire vault: verifies the current password, derives a new
    /// key from `new`, decrypts every encrypted blob with the current key, and
    /// re-encrypts each one with the new key. Keychain (salt, verification
    /// hash, biometric-protected key) is written last so a failure mid-flight
    /// can be rolled back without locking the user out of their data.
    ///
    /// `items` should be every `VaultItem` in the model context (including
    /// trashed/archived) so nothing is left encrypted under the old key.
    /// Caller is responsible for `modelContext.save()` after this returns.
    /// Pass `current = nil` when the caller has already confirmed the user via
    /// biometrics (or is otherwise authorising the change against the existing
    /// unlocked session). The in-memory `derivedKey` is then used as the
    /// "current key" — typing the old password isn't required.
    /// `forceClearUndecryptable` opts past the safety net that fires when
    /// most/all item passwords fail to decrypt with the current key. Use it
    /// when the user has explicitly acknowledged that the encrypted data is
    /// already lost (e.g. a stale biometric key) and wants to proceed anyway
    /// — the metadata (title, username, URL) survives, the encrypted blobs
    /// get cleared.
    func changeMasterPassword(
        current: String?,
        new: String,
        enableTouchID: Bool,
        items: [VaultItem],
        forceClearUndecryptable: Bool = false
    ) async throws -> ChangeMasterPasswordResult {
        isLoading = true
        defer { isLoading = false }

        guard let oldSalt = KeychainManager.load(for: .salt),
              let oldHash = KeychainManager.load(for: .verificationHash) else {
            throw ChangeMasterPasswordError.vaultMissing
        }

        let currentKey: SymmetricKey
        if let current, !current.isEmpty {
            // Verify the typed password against the stored verification hash.
            // PBKDF2 at 600k iterations blocks for ~600ms — run off-main.
            let derived = await Task.detached(priority: .userInitiated) {
                KeyDerivation.deriveKey(from: current, salt: oldSalt)
            }.value
            let derivedHash = KeyDerivation.createVerificationHash(from: derived)
            guard constantTimeEqual(derivedHash, oldHash) else {
                throw ChangeMasterPasswordError.incorrectCurrentPassword
            }
            currentKey = derived
        } else {
            // Reuse the in-memory key from the existing unlocked session.
            // Caller must have authenticated the user another way (biometrics).
            guard isUnlocked, let inMemory = derivedKey else {
                throw ChangeMasterPasswordError.notUnlocked
            }
            currentKey = inMemory
        }

        guard new.count >= 8 else {
            throw ChangeMasterPasswordError.newPasswordTooShort
        }
        if let current, new == current {
            throw ChangeMasterPasswordError.sameAsCurrent
        }

        let newSalt = KeyDerivation.generateSalt()
        let newKey = await Task.detached(priority: .userInitiated) {
            KeyDerivation.deriveKey(from: new, salt: newSalt)
        }.value
        let newHash = KeyDerivation.createVerificationHash(from: newKey)

        // Phase 1: compute every new ciphertext while keeping the originals
        // around. Nothing is mutated yet, so any decryption failure aborts
        // cleanly with the vault untouched.
        struct Pending {
            let item: VaultItem
            let password: Data
            let notes: Data?
            let cardNumber: Data?
            let cardExpiration: Data?
            let cardCVV: Data?
            let fields: Data?
            let oldPassword: Data
            let oldNotes: Data?
            let oldCardNumber: Data?
            let oldCardExpiration: Data?
            let oldCardCVV: Data?
            let oldFields: Data?
        }

        var pending: [Pending] = []
        pending.reserveCapacity(items.count)

        // Tolerate individual field failures: blobs that can't be decrypted
        // with the current key are treated as orphan/legacy data and cleared.
        // We still abort if too many *password* fields fail at once, since
        // that points at a wrong key rather than per-item corruption.
        var clearedFields = 0
        var passwordFailures = 0
        var nonEmptyPasswordCount = 0

        for item in items {
            let newPassword: Data
            if item.encryptedPassword.isEmpty {
                newPassword = Data()
            } else {
                nonEmptyPasswordCount += 1
                if let plain = item.decryptedPassword(using: currentKey) {
                    newPassword = try CryptoManager.encrypt(plain, using: newKey)
                } else {
                    newPassword = Data()
                    clearedFields += 1
                    passwordFailures += 1
                    print("changeMasterPassword: clearing undecryptable encryptedPassword on item \(item.id)")
                }
            }

            let (newNotes, notesCleared) = reEncryptOrClear(item.encryptedNotes, currentKey: currentKey, newKey: newKey)
            let (newCardNumber, cnCleared) = reEncryptOrClear(item.encryptedCardNumber, currentKey: currentKey, newKey: newKey)
            let (newCardExpiration, ceCleared) = reEncryptOrClear(item.encryptedCardExpiration, currentKey: currentKey, newKey: newKey)
            let (newCardCVV, cvvCleared) = reEncryptOrClear(item.encryptedCardCVV, currentKey: currentKey, newKey: newKey)
            let (newFields, fieldsCleared) = reEncryptOrClear(item.encryptedFields, currentKey: currentKey, newKey: newKey)
            clearedFields += [notesCleared, cnCleared, ceCleared, cvvCleared, fieldsCleared].filter { $0 }.count

            pending.append(Pending(
                item: item,
                password: newPassword, notes: newNotes,
                cardNumber: newCardNumber, cardExpiration: newCardExpiration, cardCVV: newCardCVV,
                fields: newFields,
                oldPassword: item.encryptedPassword, oldNotes: item.encryptedNotes,
                oldCardNumber: item.encryptedCardNumber, oldCardExpiration: item.encryptedCardExpiration,
                oldCardCVV: item.encryptedCardCVV, oldFields: item.encryptedFields
            ))
        }

        // If a meaningful share of password fields failed, the current key is
        // probably wrong. Bail before touching the keychain — unless the
        // caller has explicitly opted to proceed anyway and accept the loss.
        if nonEmptyPasswordCount > 0, passwordFailures * 2 > nonEmptyPasswordCount, !forceClearUndecryptable {
            throw ChangeMasterPasswordError.massDecryptionFailure(failed: passwordFailures, total: nonEmptyPasswordCount)
        }

        // Phase 2: apply all new ciphertexts in memory.
        for p in pending {
            p.item.encryptedPassword = p.password
            p.item.encryptedNotes = p.notes
            p.item.encryptedCardNumber = p.cardNumber
            p.item.encryptedCardExpiration = p.cardExpiration
            p.item.encryptedCardCVV = p.cardCVV
            p.item.encryptedFields = p.fields
        }

        // Phase 3: commit new keychain entries. If any step fails, undo every
        // in-memory mutation and put the previous keychain values back.
        do {
            try KeychainManager.save(newSalt, for: .salt)
            try KeychainManager.save(newHash, for: .verificationHash)
            if enableTouchID && BiometricAuth.isAvailable {
                let keyData = newKey.withUnsafeBytes { Data($0) }
                do {
                    try KeychainManager.saveBiometricProtectedKey(keyData)
                    self.touchIDEnabled = true
                } catch {
                    print("Re-keying Touch ID failed (non-fatal): \(error)")
                    self.touchIDEnabled = false
                }
            } else {
                KeychainManager.delete(for: .biometricKey)
                self.touchIDEnabled = false
            }
        } catch {
            for p in pending {
                p.item.encryptedPassword = p.oldPassword
                p.item.encryptedNotes = p.oldNotes
                p.item.encryptedCardNumber = p.oldCardNumber
                p.item.encryptedCardExpiration = p.oldCardExpiration
                p.item.encryptedCardCVV = p.oldCardCVV
                p.item.encryptedFields = p.oldFields
            }
            try? KeychainManager.save(oldSalt, for: .salt)
            try? KeychainManager.save(oldHash, for: .verificationHash)
            throw ChangeMasterPasswordError.keychainWriteFailed(error)
        }

        self.derivedKey = newKey
        resetInactivityTimer()
        rotateExtensionTokenAfterAuth()

        return ChangeMasterPasswordResult(totalItems: items.count, clearedFields: clearedFields)
    }

    /// Re-encrypts an optional ciphertext under the new key. Returns the
    /// rewritten data and a flag indicating whether the original was
    /// undecryptable (and therefore cleared in the new vault).
    private func reEncryptOrClear(
        _ data: Data?,
        currentKey: SymmetricKey,
        newKey: SymmetricKey
    ) -> (Data?, cleared: Bool) {
        guard let data, !data.isEmpty else { return (data, false) }
        guard let plain = try? CryptoManager.decrypt(data, using: currentKey) else {
            return (nil, true)
        }
        guard let reencrypted = try? CryptoManager.encrypt(plain, using: newKey) else {
            return (nil, true)
        }
        return (reencrypted, false)
    }

    private func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }

    /// Rotates the IPC bearer token used by the Safari extension. Invoked after
    /// every auth success (unlock, biometric unlock, vault setup, re-key) so
    /// any token previously cached by the extension expires with the prior
    /// session. Failures are non-fatal: the existing token continues to work.
    private func rotateExtensionTokenAfterAuth() {
        do {
            let newToken = try KeychainManager.rotateIPCToken()
            ExtensionServer.shared.updateTokenCache(newToken)
        } catch {
            print("IPC token rotation failed (non-fatal): \(error)")
        }
    }

    // MARK: - Lock

    /// Locks the vault and clears the derived key from memory.
    func lock() {
        isUnlocked = false
        derivedKey = nil
        errorMessage = nil
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        stopActivityTracking()
    }

    /// Resets the inactivity auto-lock timer.
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        let timeout = lockTimeout
        guard timeout > 0, isUnlocked else { return }
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }

    /// Installs a local NSEvent monitor that resets the inactivity timer on
    /// any user-driven input directed at the app while it is unlocked. Without
    /// this hook the "auto-lock" timer simply fires N seconds after unlock
    /// regardless of whether the user is actively using the vault.
    private func startActivityTracking() {
        #if os(macOS)
        guard activityMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .scrollWheel, .mouseMoved, .leftMouseDragged, .rightMouseDragged
        ]
        activityMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            // Coalesce mouse-moved noise: only nudge the timer at most once per second.
            self?.noteActivity()
            return event
        }
        #endif
    }

    private func stopActivityTracking() {
        #if os(macOS)
        if let monitor = activityMonitor {
            NSEvent.removeMonitor(monitor)
            activityMonitor = nil
        }
        lastActivityNudge = .distantPast
        #endif
    }

    private var lastActivityNudge: Date = .distantPast
    private func noteActivity() {
        let now = Date()
        guard now.timeIntervalSince(lastActivityNudge) >= 1.0 else { return }
        lastActivityNudge = now
        resetInactivityTimer()
    }
}

struct ChangeMasterPasswordResult {
    let totalItems: Int
    /// Total number of encrypted fields (across all items) that could not be
    /// decrypted with the current key and were cleared in the new vault.
    let clearedFields: Int
}

enum ChangeMasterPasswordError: LocalizedError {
    case vaultMissing
    case notUnlocked
    case incorrectCurrentPassword
    case newPasswordTooShort
    case sameAsCurrent
    case massDecryptionFailure(failed: Int, total: Int)
    case keychainWriteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .vaultMissing:
            return "Vault data not found. Set up a vault first."
        case .notUnlocked:
            return "Vault must be unlocked to change the master password."
        case .incorrectCurrentPassword:
            return "Current master password is incorrect."
        case .newPasswordTooShort:
            return "New master password must be at least 8 characters."
        case .sameAsCurrent:
            return "New password must differ from the current one."
        case .massDecryptionFailure(let failed, let total):
            return "Could not decrypt \(failed) of \(total) item passwords with the current key. The session key may be out of sync with the stored data — try locking and unlocking with your master password before retrying."
        case .keychainWriteFailed(let error):
            return "Could not update Keychain: \(error.localizedDescription)"
        }
    }
}
