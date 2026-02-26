import SwiftUI

/// Configurable password generator with strength indicator.
struct PasswordGeneratorView: View {
    var onUsePassword: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var generator = PasswordGenerator()
    @State private var generatedPassword = ""
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.fpAccentPurple)
                Text("Password Generator")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.fpTextPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.fpTextTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(Color.fpSurfaceBorder)

            VStack(spacing: 20) {
                // Generated password display
                VStack(spacing: 8) {
                    Text(generatedPassword)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.fpTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.fpBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.fpSurfaceBorder, lineWidth: 1)
                        )

                    // Strength bar
                    let strength = PasswordGenerator.evaluateStrength(generatedPassword)
                    HStack(spacing: 4) {
                        ForEach(PasswordStrength.allCases, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(level.rawValue <= strength.rawValue
                                      ? strength.color
                                      : Color.fpSurfaceBorder)
                                .frame(height: 4)
                        }
                    }
                    Text(strength.label)
                        .font(.caption2)
                        .foregroundColor(strength.color)
                }

                // Length slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Length")
                            .font(.caption)
                            .foregroundColor(.fpTextSecondary)
                        Spacer()
                        Text("\(generator.length)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.fpAccentPurple)
                    }
                    Slider(value: Binding(
                        get: { Double(generator.length) },
                        set: { generator.length = Int($0) }
                    ), in: 8...64, step: 1)
                    .tint(.fpAccentPurple)
                    .onChange(of: generator.length) { _, _ in regenerate() }
                }

                // Character toggles
                VStack(spacing: 10) {
                    characterToggle("Uppercase (A-Z)", isOn: $generator.includeUppercase, icon: "textformat.abc")
                    characterToggle("Lowercase (a-z)", isOn: $generator.includeLowercase, icon: "textformat.abc")
                    characterToggle("Digits (0-9)", isOn: $generator.includeDigits, icon: "number")
                    characterToggle("Symbols (!@#$)", isOn: $generator.includeSymbols, icon: "number.square")
                }
            }
            .padding(20)

            Spacer()

            Divider().background(Color.fpSurfaceBorder)

            // Actions
            HStack(spacing: 12) {
                Button {
                    regenerate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Regenerate")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)

                Button {
                    ClipboardManager.shared.copy(generatedPassword)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                if let onUse = onUsePassword {
                    Button {
                        onUse(generatedPassword)
                    } label: {
                        Text("Use Password")
                    }
                    .buttonStyle(FPGradientButtonStyle())
                    .frame(width: 140)
                }
            }
            .padding(20)
        }
        .background(Color.fpSurface)
        .onAppear { regenerate() }
    }

    private func characterToggle(_ label: String, isOn: Binding<Bool>, icon: String) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.fpAccentPurple)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.fpTextPrimary)
            }
        }
        .toggleStyle(.switch)
        .tint(.fpAccentPurple)
        .onChange(of: isOn.wrappedValue) { _, _ in regenerate() }
    }

    private func regenerate() {
        generatedPassword = generator.generate()
    }
}
