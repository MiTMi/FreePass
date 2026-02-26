import SwiftUI

// MARK: - Color Palette

extension Color {
    // Backgrounds
    static let fpBackground = Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))
    static let fpSurface = Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1))
    static let fpSurfaceHover = Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1))
    static let fpSurfaceBorder = Color(white: 0.2)

    // Accent
    static let fpAccentPurple = Color(red: 0.45, green: 0.30, blue: 1.0)
    static let fpAccentBlue = Color(red: 0.25, green: 0.55, blue: 1.0)
    static let fpAccentCyan = Color(red: 0.20, green: 0.75, blue: 0.95)

    // Text
    static let fpTextPrimary = Color.white
    static let fpTextSecondary = Color(white: 0.55)
    static let fpTextTertiary = Color(white: 0.35)

    // Semantic
    static let fpDanger = Color(red: 1.0, green: 0.35, blue: 0.40)
    static let fpSuccess = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let fpWarning = Color(red: 1.0, green: 0.75, blue: 0.25)

    // Gradients
    static var fpGradient: LinearGradient {
        LinearGradient(
            colors: [fpAccentPurple, fpAccentBlue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var fpGradientVertical: LinearGradient {
        LinearGradient(
            colors: [fpAccentPurple, fpAccentBlue],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Password Strength Colors

extension PasswordStrength {
    var color: Color {
        switch self {
        case .veryWeak: return .fpDanger
        case .weak: return .orange
        case .fair: return .fpWarning
        case .strong: return .fpSuccess
        case .veryStrong: return Color(red: 0.15, green: 0.90, blue: 0.60)
        }
    }
}

// MARK: - Custom View Modifiers

struct FPCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.fpSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.fpSurfaceBorder, lineWidth: 0.5)
            )
    }
}

struct FPGradientButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isEnabled
                    ? AnyShapeStyle(Color.fpGradient)
                    : AnyShapeStyle(Color.fpSurfaceHover)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct FPTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.fpBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.fpSurfaceBorder, lineWidth: 1)
            )
    }
}

extension View {
    func fpCard() -> some View {
        modifier(FPCardStyle())
    }

    func fpTextField() -> some View {
        modifier(FPTextFieldStyle())
    }
}
