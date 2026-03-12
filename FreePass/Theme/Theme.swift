import AppKit
import SwiftUI

// MARK: - Color Palette

extension Color {
    // Helper for generating dynamic colors that respond instantly to Light/Dark mode
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.name == .darkAqua || appearance.name == .vibrantDark || appearance.name == .accessibilityHighContrastDarkAqua || appearance.name == .accessibilityHighContrastVibrantDark {
                return dark
            } else {
                return light
            }
        }))
    }
    
    // Backgrounds
    static let fpBackground = dynamic(
        light: NSColor(red: 244.0/255.0, green: 245.0/255.0, blue: 247.0/255.0, alpha: 1.0),
        dark: NSColor(red: 38.0/255.0, green: 38.0/255.0, blue: 38.0/255.0, alpha: 1.0)
    )
    static let fpSidebar = dynamic(
        light: NSColor(red: 244.0/255.0, green: 245.0/255.0, blue: 247.0/255.0, alpha: 1.0),
        dark: NSColor(red: 43.0/255.0, green: 43.0/255.0, blue: 48.0/255.0, alpha: 1.0)
    )
    static let fpList = dynamic(
        light: NSColor.white,
        dark: NSColor(red: 43.0/255.0, green: 43.0/255.0, blue: 43.0/255.0, alpha: 1.0)
    )
    static let fpDetail = dynamic(
        light: NSColor.white,
        dark: NSColor(red: 43.0/255.0, green: 43.0/255.0, blue: 43.0/255.0, alpha: 1.0)
    )
    static let fpSurface = dynamic(
        light: NSColor.white,
        dark: NSColor(red: 50.0/255.0, green: 50.0/255.0, blue: 50.0/255.0, alpha: 1.0)
    )
    static let fpSurfaceHover = dynamic(
        light: NSColor(white: 0.95, alpha: 1.0),
        dark: NSColor(red: 65.0/255.0, green: 65.0/255.0, blue: 65.0/255.0, alpha: 1.0)
    )
    static let fpSurfaceBorder = dynamic(
        light: NSColor(white: 0.85, alpha: 1.0),
        dark: NSColor(white: 0.2, alpha: 1.0)
    )
    static let fpSelection = Color(red: 0.05, green: 0.38, blue: 0.95)

    // Accent
    static let fpAccentPurple = Color(red: 0.45, green: 0.30, blue: 1.0)
    static let fpAccentBlue = Color(red: 0.25, green: 0.55, blue: 1.0)
    static let fpAccentCyan = Color(red: 0.20, green: 0.75, blue: 0.95)

    // Text
    static let fpTextPrimary = dynamic(
        light: NSColor.black,
        dark: NSColor.white
    )
    static let fpTextSecondary = dynamic(
        light: NSColor.systemGray,
        dark: NSColor(white: 0.55, alpha: 1.0)
    )
    static let fpTextTertiary = dynamic(
        light: NSColor.lightGray,
        dark: NSColor(white: 0.35, alpha: 1.0)
    )

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

    /// Applies a premium "Liquid Glass" effect to a view.
    func liquidGlass(material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) -> some View {
        self.background(VisualEffectView(material: material, blendingMode: blendingMode))
            .overlay(
                ZStack {
                    // Intense liquid sheen from top
                    LinearGradient(
                        colors: [.white.opacity(0.12), .clear, .white.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Glass highlight line at the very top
                    VStack {
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 0.5)
                        Spacer()
                    }
                    
                    // Edge Prism (thickness)
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear, .black.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
    }
}

// MARK: - AppKit Bridges

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
