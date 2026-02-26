import SwiftUI

/// Unlock screen shown on subsequent launches.
struct UnlockView: View {
    @Environment(AppState.self) private var appState
    @State private var password = ""
    @State private var shake = false
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Lock icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.fpAccentPurple.opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 15,
                                endRadius: 70
                            )
                        )
                        .frame(width: 110, height: 110)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(Color.fpGradient)
                }
                .scaleEffect(animateIn ? 1.0 : 0.6)
                .opacity(animateIn ? 1.0 : 0)

                // Title
                VStack(spacing: 6) {
                    Text("FreePass")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.fpTextPrimary)

                    Text("Enter your master password to unlock")
                        .font(.system(size: 13))
                        .foregroundColor(.fpTextSecondary)
                }
                .opacity(animateIn ? 1.0 : 0)

                // Password field
                VStack(spacing: 12) {
                    SecureField("Master Password", text: $password)
                        .fpTextField()
                        .onSubmit { attemptUnlock() }
                        .offset(x: shake ? -8 : 0)
                        .animation(
                            shake
                                ? .default.repeatCount(4, autoreverses: true).speed(6)
                                : .default,
                            value: shake
                        )

                    // Error message
                    if let error = appState.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.fpDanger)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Unlock button
                    Button {
                        attemptUnlock()
                    } label: {
                        HStack {
                            if appState.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.7)
                            }
                            Text("Unlock")
                        }
                    }
                    .buttonStyle(FPGradientButtonStyle(isEnabled: !password.isEmpty))
                    .disabled(password.isEmpty || appState.isLoading)

                    // Touch ID button
                    if BiometricAuth.isAvailable {
                        Button {
                            Task { await appState.unlockWithBiometrics() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "touchid")
                                Text("Unlock with \(BiometricAuth.biometricType)")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.fpAccentBlue)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: 320)
                .opacity(animateIn ? 1.0 : 0)
                .offset(y: animateIn ? 0 : 15)
            }
            .padding(40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBackground)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
    }

    private func attemptUnlock() {
        let success = appState.unlock(with: password)
        if !success {
            password = ""
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shake = false
            }
        }
    }
}
