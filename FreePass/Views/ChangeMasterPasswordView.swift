import SwiftUI
import SwiftData

/// Sheet for re-keying the vault. The user can either type their current
/// master password OR — if the vault is already unlocked and biometrics are
/// available — fall back to a Touch ID re-prompt that authorises the change
/// against the in-memory derived key. The heavy work happens in
/// `AppState.changeMasterPassword`.
struct ChangeMasterPasswordView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [VaultItem]

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var enableTouchID = true
    @State private var errorText: String?
    @State private var isWorking = false
    @State private var didSucceed = false
    @State private var verifiedViaBiometrics = false
    @State private var isVerifyingBiometrics = false
    @State private var clearedFields = 0
    @State private var massFailureFailed = 0
    @State private var massFailureTotal = 0

    private var passwordStrength: PasswordStrength {
        PasswordGenerator.evaluateStrength(newPassword)
    }

    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    private var biometricsAvailable: Bool {
        BiometricAuth.isAvailable && appState.isUnlocked
    }

    private var isFormValid: Bool {
        let credentialOK = verifiedViaBiometrics || !currentPassword.isEmpty
        let differs = verifiedViaBiometrics || newPassword != currentPassword
        return credentialOK && newPassword.count >= 8 && passwordsMatch && differs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if didSucceed {
                successCard
            } else {
                form
            }
            Spacer(minLength: 0)
            buttons
        }
        .padding(28)
        .frame(width: 460)
        .frame(minHeight: didSucceed ? 320 : 560)
        .background(Color.fpBackground)
        .onAppear {
            enableTouchID = appState.touchIDEnabled && BiometricAuth.isAvailable
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(didSucceed ? "Master Password Changed" : "Change Master Password")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.fpTextPrimary)
            Text(didSucceed
                 ? "Your vault has been re-encrypted with the new key."
                 : "Your vault will be re-encrypted in place. This can take a few seconds.")
                .font(.callout)
                .foregroundColor(.fpTextSecondary)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            currentCredentialSection

            VStack(alignment: .leading, spacing: 6) {
                Text("New Master Password")
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                SecureField("At least 8 characters", text: $newPassword)
                    .fpTextField()
                if !newPassword.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(PasswordStrength.allCases, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(level.rawValue <= passwordStrength.rawValue
                                      ? passwordStrength.color
                                      : Color.fpSurfaceBorder)
                                .frame(height: 3)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: passwordStrength)
                    Text(passwordStrength.label)
                        .font(.caption2)
                        .foregroundColor(passwordStrength.color)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm New Password")
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                SecureField("Re-enter new password", text: $confirmPassword)
                    .fpTextField()
                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords do not match")
                        .font(.caption2)
                        .foregroundColor(.fpDanger)
                }
            }

            if BiometricAuth.isAvailable {
                Toggle(isOn: $enableTouchID) {
                    HStack(spacing: 8) {
                        Image(systemName: "touchid")
                            .foregroundColor(.fpAccentPurple)
                        Text("Re-enable \(BiometricAuth.biometricType)")
                            .foregroundColor(.fpTextPrimary)
                    }
                }
                .toggleStyle(.switch)
                .tint(.fpAccentPurple)
            }

            if let errorText {
                VStack(alignment: .leading, spacing: 10) {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.fpDanger)
                    if massFailureTotal > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recovery option")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.fpTextSecondary)
                            Text("Set a new password anyway. The \(massFailureFailed) unreadable password\(massFailureFailed == 1 ? "" : "s") and any other undecryptable fields will be cleared. Titles, usernames, URLs, and categories are not encrypted and will be preserved.")
                                .font(.caption)
                                .foregroundColor(.fpTextSecondary)
                            Button {
                                Task { await submit(force: true) }
                            } label: {
                                HStack(spacing: 6) {
                                    if isWorking {
                                        ProgressView().scaleEffect(0.6)
                                    }
                                    Text("Change Password & Clear Unreadable Fields")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.fpDanger)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.fpDanger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var currentCredentialSection: some View {
        if verifiedViaBiometrics {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.fpSuccess)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verified with \(BiometricAuth.biometricType)")
                        .font(.callout)
                        .foregroundColor(.fpTextPrimary)
                    Text("You can set a new master password without the old one.")
                        .font(.caption2)
                        .foregroundColor(.fpTextSecondary)
                }
                Spacer()
                Button("Undo") {
                    verifiedViaBiometrics = false
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.fpAccentBlue)
            }
            .padding(12)
            .background(Color.fpSuccess.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Master Password")
                    .font(.caption)
                    .foregroundColor(.fpTextSecondary)
                SecureField("Enter current password", text: $currentPassword)
                    .fpTextField()
                if biometricsAvailable {
                    Button {
                        Task { await verifyWithBiometrics() }
                    } label: {
                        HStack(spacing: 6) {
                            if isVerifyingBiometrics {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "touchid")
                            }
                            Text("Forgot it? Verify with \(BiometricAuth.biometricType)")
                        }
                        .font(.caption)
                        .foregroundColor(.fpAccentBlue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isVerifyingBiometrics)
                }
            }
        }
    }

    private var successCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundColor(.fpSuccess)
            Text("\(allItems.count) item\(allItems.count == 1 ? "" : "s") re-encrypted.")
                .font(.callout)
                .foregroundColor(.fpTextSecondary)
            if clearedFields > 0 {
                Label(
                    "\(clearedFields) field\(clearedFields == 1 ? "" : "s") could not be decrypted with the current key and \(clearedFields == 1 ? "was" : "were") cleared. The other fields on those items are intact.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundColor(.fpWarning)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.fpWarning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var buttons: some View {
        HStack {
            if !didSucceed {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.fpTextSecondary)
            }
            Spacer()
            if didSucceed {
                Button("Done") { dismiss() }
                    .buttonStyle(FPGradientButtonStyle(isEnabled: true))
                    .frame(width: 140)
            } else {
                Button {
                    Task { await submit(force: false) }
                } label: {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.7)
                        }
                        Text(isWorking ? "Re-encrypting…" : "Change Password")
                    }
                }
                .buttonStyle(FPGradientButtonStyle(isEnabled: isFormValid && !isWorking))
                .disabled(!isFormValid || isWorking)
                .frame(width: 200)
            }
        }
    }

    // MARK: - Actions

    private func verifyWithBiometrics() async {
        errorText = nil
        isVerifyingBiometrics = true
        defer { isVerifyingBiometrics = false }
        let ok = await BiometricAuth.evaluate(reason: "Verify to change your master password")
        if ok {
            verifiedViaBiometrics = true
            currentPassword = ""
        } else {
            errorText = "\(BiometricAuth.biometricType) verification was cancelled or failed."
        }
    }

    private func submit(force: Bool) async {
        errorText = nil
        if !force {
            massFailureFailed = 0
            massFailureTotal = 0
        }
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await appState.changeMasterPassword(
                current: verifiedViaBiometrics ? nil : currentPassword,
                new: newPassword,
                enableTouchID: enableTouchID,
                items: allItems,
                forceClearUndecryptable: force
            )
            try modelContext.save()
            clearedFields = result.clearedFields
            didSucceed = true
        } catch let err as ChangeMasterPasswordError {
            if case .massDecryptionFailure(let failed, let total) = err {
                massFailureFailed = failed
                massFailureTotal = total
            }
            errorText = err.localizedDescription
        } catch {
            errorText = error.localizedDescription
        }
    }
}
