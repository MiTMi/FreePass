import SwiftUI

/// First-launch screen where the user creates their master password.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var enableTouchID = true
    @State private var showError = false
    @State private var errorText = ""
    @State private var animateIn = false

    private var passwordStrength: PasswordStrength {
        PasswordGenerator.evaluateStrength(password)
    }

    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    private var isFormValid: Bool {
        password.count >= 8 && passwordsMatch
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.fpAccentPurple.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(animateIn ? 1.0 : 0.5)
                .opacity(animateIn ? 1.0 : 0)

                // Title
                VStack(spacing: 8) {
                    Text("Welcome to FreePass")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.fpTextPrimary)

                    Text("Create a master password to protect your vault")
                        .font(.system(size: 14))
                        .foregroundColor(.fpTextSecondary)
                }
                .opacity(animateIn ? 1.0 : 0)
                .offset(y: animateIn ? 0 : 10)

                // Form
                VStack(spacing: 16) {
                    // Master Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Master Password")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)

                        SecureField("At least 8 characters", text: $password)
                            .fpTextField()

                        // Strength indicator
                        if !password.isEmpty {
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

                    // Confirm Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)

                        SecureField("Re-enter your password", text: $confirmPassword)
                            .fpTextField()

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption2)
                                .foregroundColor(.fpDanger)
                        }
                    }

                    // Touch ID toggle
                    if BiometricAuth.isAvailable {
                        Toggle(isOn: $enableTouchID) {
                            HStack(spacing: 8) {
                                Image(systemName: "touchid")
                                    .foregroundColor(.fpAccentPurple)
                                Text("Enable \(BiometricAuth.biometricType)")
                                    .foregroundColor(.fpTextPrimary)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(.fpAccentPurple)
                        .padding(.top, 4)
                    }
                }
                .padding(24)
                .background(Color.fpSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.fpSurfaceBorder, lineWidth: 0.5)
                )
                .opacity(animateIn ? 1.0 : 0)
                .offset(y: animateIn ? 0 : 20)

                // Error
                if showError {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(.fpDanger)
                        .transition(.opacity)
                }

                // Create button
                Button {
                    createVault()
                } label: {
                    HStack {
                        if appState.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.7)
                        }
                        Text("Create Vault")
                    }
                }
                .buttonStyle(FPGradientButtonStyle(isEnabled: isFormValid))
                .disabled(!isFormValid || appState.isLoading)
                .opacity(animateIn ? 1.0 : 0)
                .offset(y: animateIn ? 0 : 20)
            }
            .frame(maxWidth: 380)
            .padding(40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBackground)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateIn = true
            }
        }
    }

    private func createVault() {
        do {
            try appState.setupMasterPassword(password, enableTouchID: enableTouchID)
        } catch {
            errorText = error.localizedDescription
            showError = true
        }
    }
}
