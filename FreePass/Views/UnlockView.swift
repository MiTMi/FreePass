import SwiftUI

/// Unlock screen shown on subsequent launches.
struct UnlockView: View {
    @Environment(AppState.self) private var appState
    @State private var password = ""
    @State private var shake = false
    @State private var animateIn = false
    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool

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

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
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
                VStack(spacing: 20) {
                    HStack(spacing: 14) {
                        if isPasswordVisible {
                            TextField("Enter your password", text: $password)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .onSubmit { attemptUnlock() }
                                .font(.system(size: 16))
                        } else {
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .onSubmit { attemptUnlock() }
                                .font(.system(size: 16))
                        }
                        
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                .foregroundColor(.fpAccentBlue.opacity(0.8))
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                        
                        if appState.touchIDEnabled && BiometricAuth.isAvailable {
                            Rectangle()
                                .fill(Color.fpSurfaceBorder)
                                .frame(width: 1, height: 26)
                            
                            Button {
                                Task { await appState.unlockWithBiometrics() }
                            } label: {
                                Image(systemName: "touchid")
                                    .foregroundColor(.fpAccentBlue)
                                    .font(.system(size: 26, weight: .regular))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isFocused ? Color.fpAccentBlue : Color.fpAccentBlue.opacity(0.4),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
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
            
            // Auto-trigger Touch ID on app launch if enabled
            if appState.touchIDEnabled && BiometricAuth.isAvailable && !appState.hasPromptedForTouchIDOnLaunch {
                appState.hasPromptedForTouchIDOnLaunch = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if !appState.isUnlocked {
                        Task { await appState.unlockWithBiometrics() }
                    }
                }
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
