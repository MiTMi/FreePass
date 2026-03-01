import Foundation
import CryptoKit
import SwiftUI

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
    private(set) var isLoading = false

    private var inactivityTimer: Timer?
    private let lockTimeout: TimeInterval = 300 // 5 minutes

    init() {
        checkFirstLaunch()
    }

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
            resetInactivityTimer()
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

        if verificationHash == storedHash {
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
            resetInactivityTimer()
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
                        self.resetInactivityTimer()
                        continuation.resume(returning: true)
                    }
                } catch {
                    Task { @MainActor in
                        if let keychainErr = error as? KeychainError, case .loadFailed(let status) = keychainErr {
                            self.errorMessage = "Touch ID authentication failed (status: \(status))."
                        } else {
                            self.errorMessage = "Touch ID authentication failed."
                        }
                        continuation.resume(returning: false)
                    }
                }
            }
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
    }

    /// Resets the inactivity auto-lock timer.
    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: lockTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }
}
