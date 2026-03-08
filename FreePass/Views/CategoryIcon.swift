import SwiftUI

// MARK: - Category Icon

/// Premium app-icon-style category icon matching 1Password's visual quality.
/// Layered gradient background + oversized SF Symbol + gloss overlay.
struct CategoryIcon: View {
    let category: VaultCategory
    let size: CGFloat

    init(_ category: VaultCategory, size: CGFloat = 40) {
        self.category = category
        self.size = size
    }

    var body: some View {
        ZStack {
            // 1. Gradient background
            RoundedRectangle(cornerRadius: size * 0.2222, style: .continuous)
                .fill(category.iconGradient)
                .frame(width: size, height: size)
                .shadow(color: category.iconShadowColor, radius: size * 0.12, x: 0, y: size * 0.06)

            // 2. Gloss highlight (top-left shimmer)
            RoundedRectangle(cornerRadius: size * 0.2222, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.6, y: 0.6)
                    )
                )
                .frame(width: size, height: size)

            // 3. Main symbol
            Image(systemName: category.primarySymbol)
                .font(.system(size: size * 0.52, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0, y: 1)

            // 4. Optional badge (secondary overlaid symbol for complex icons)
            if let badge = category.badgeSymbol {
                Image(systemName: badge.symbol)
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(badge.color)
                    .frame(width: size * 0.38, height: size * 0.38)
                    .background(
                        Circle()
                            .fill(badge.background)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
                    .offset(x: size * 0.27, y: size * 0.27)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2222, style: .continuous))
    }
}

// MARK: - Badge Model

struct IconBadge {
    let symbol: String
    let color: Color
    let background: Color
}

// MARK: - VaultCategory Icon Styling

extension VaultCategory {

    var iconGradient: LinearGradient {
        let (top, bottom) = iconGradientColors
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var iconShadowColor: Color { iconGradientColors.0.opacity(0.45) }

    /// Primary SF Symbol for the category — chosen for maximum visual clarity at small sizes.
    var primarySymbol: String {
        switch self {
        case .all:                  return "tray.full.fill"
        case .login:                return "lock.shield.fill"
        case .secureNote:           return "note.text"
        case .creditCard:           return "creditcard.fill"
        case .identity:             return "person.text.rectangle.fill"
        case .password:             return "key.horizontal.fill"
        case .document:             return "doc.richtext.fill"
        case .sshKey:               return "terminal.fill"
        case .apiCredentials:       return "chevron.left.forwardslash.chevron.right"
        case .bankAccount:          return "dollarsign.circle.fill"
        case .cryptoWallet:         return "bitcoinsign.circle.fill"
        case .database:             return "cylinder.split.1x2.fill"
        case .driverLicense:        return "car.fill"
        case .email:                return "envelope.fill"
        case .medicalRecord:        return "heart.text.square.fill"
        case .membership:           return "star.circle.fill"
        case .outdoorLicense:       return "tree.fill"
        case .passport:             return "globe.americas.fill"
        case .rewards:              return "gift.fill"
        case .server:               return "server.rack"
        case .socialSecurityNumber: return "person.badge.shield.checkmark.fill"
        case .softwareLicense:      return "checkmark.seal.fill"
        case .wirelessRouter:       return "wifi"
        case .favorites:            return "star.fill"
        }
    }

    /// Optional decorative badge overlaid in the bottom-right corner.
    var badgeSymbol: IconBadge? {
        switch self {
        case .sshKey:
            return IconBadge(
                symbol: "key.fill",
                color: Color(hue: 0.12, saturation: 0.85, brightness: 0.98),
                background: Color(hue: 0.12, saturation: 0.5, brightness: 0.3)
            )
        case .database:
            return IconBadge(
                symbol: "tablecells.fill",
                color: .white.opacity(0.9),
                background: Color(white: 0.25)
            )
        default:
            return nil
        }
    }

    var iconGradientColors: (Color, Color) {
        switch self {
        case .all:
            return (Color(hue: 0.68, saturation: 0.60, brightness: 0.85),
                    Color(hue: 0.72, saturation: 0.80, brightness: 0.60))

        case .login:
            // Vivid teal-green (1Password uses this exact hue)
            return (Color(hue: 0.47, saturation: 0.78, brightness: 0.78),
                    Color(hue: 0.44, saturation: 0.88, brightness: 0.55))

        case .secureNote:
            // Warm amber/orange notebook colour
            return (Color(hue: 0.10, saturation: 0.88, brightness: 1.0),
                    Color(hue: 0.06, saturation: 0.92, brightness: 0.82))

        case .creditCard:
            // Sky/royal blue
            return (Color(hue: 0.59, saturation: 0.72, brightness: 0.96),
                    Color(hue: 0.62, saturation: 0.90, brightness: 0.70))

        case .identity:
            // Saturated green
            return (Color(hue: 0.37, saturation: 0.72, brightness: 0.78),
                    Color(hue: 0.34, saturation: 0.88, brightness: 0.55))

        case .password:
            // Deep teal (darker than Login)
            return (Color(hue: 0.49, saturation: 0.80, brightness: 0.62),
                    Color(hue: 0.46, saturation: 0.90, brightness: 0.42))

        case .document:
            // Slate periwinkle blue
            return (Color(hue: 0.61, saturation: 0.60, brightness: 0.88),
                    Color(hue: 0.63, saturation: 0.80, brightness: 0.65))

        case .sshKey:
            // Dark charcoal (the terminal green-black look)
            return (Color(hue: 0.33, saturation: 0.15, brightness: 0.38),
                    Color(hue: 0.33, saturation: 0.10, brightness: 0.22))

        case .apiCredentials:
            // Teal-green (same family as 1Password API icon)
            return (Color(hue: 0.50, saturation: 0.78, brightness: 0.75),
                    Color(hue: 0.47, saturation: 0.90, brightness: 0.52))

        case .bankAccount:
            // Rich gold/amber circle
            return (Color(hue: 0.11, saturation: 0.88, brightness: 1.0),
                    Color(hue: 0.08, saturation: 0.92, brightness: 0.78))

        case .cryptoWallet:
            // Indigo/purple-blue
            return (Color(hue: 0.77, saturation: 0.62, brightness: 0.88),
                    Color(hue: 0.73, saturation: 0.78, brightness: 0.65))

        case .database:
            // Gunmetal grey
            return (Color(hue: 0.60, saturation: 0.08, brightness: 0.45),
                    Color(hue: 0.60, saturation: 0.10, brightness: 0.28))

        case .driverLicense:
            // Coral pink (car icon, pink bg)
            return (Color(hue: 0.96, saturation: 0.62, brightness: 0.94),
                    Color(hue: 0.93, saturation: 0.75, brightness: 0.72))

        case .email:
            // Vivid magenta/hot pink
            return (Color(hue: 0.87, saturation: 0.75, brightness: 0.90),
                    Color(hue: 0.84, saturation: 0.88, brightness: 0.68))

        case .medicalRecord:
            // Soft white-pink
            return (Color(hue: 0.00, saturation: 0.08, brightness: 0.92),
                    Color(hue: 0.97, saturation: 0.18, brightness: 0.76))

        case .membership:
            // Medium violet/purple
            return (Color(hue: 0.76, saturation: 0.62, brightness: 0.82),
                    Color(hue: 0.73, saturation: 0.78, brightness: 0.60))

        case .outdoorLicense:
            // Forest teal-green
            return (Color(hue: 0.46, saturation: 0.75, brightness: 0.70),
                    Color(hue: 0.42, saturation: 0.88, brightness: 0.48))

        case .passport:
            // Cobalt blue globe
            return (Color(hue: 0.60, saturation: 0.82, brightness: 0.90),
                    Color(hue: 0.62, saturation: 0.92, brightness: 0.62))

        case .rewards:
            // Hot pink gift
            return (Color(hue: 0.91, saturation: 0.72, brightness: 0.96),
                    Color(hue: 0.87, saturation: 0.82, brightness: 0.76))

        case .server:
            // Blue-grey rack
            return (Color(hue: 0.59, saturation: 0.18, brightness: 0.58),
                    Color(hue: 0.59, saturation: 0.22, brightness: 0.36))

        case .socialSecurityNumber:
            // Deep royal blue
            return (Color(hue: 0.63, saturation: 0.72, brightness: 0.88),
                    Color(hue: 0.65, saturation: 0.88, brightness: 0.60))

        case .softwareLicense:
            // Cyan/sky blue seal
            return (Color(hue: 0.56, saturation: 0.82, brightness: 0.92),
                    Color(hue: 0.58, saturation: 0.92, brightness: 0.68))

        case .wirelessRouter:
            // Bright sky blue
            return (Color(hue: 0.56, saturation: 0.72, brightness: 0.94),
                    Color(hue: 0.57, saturation: 0.88, brightness: 0.70))

        case .favorites:
            return (Color(hue: 0.12, saturation: 0.88, brightness: 1.0),
                    Color(hue: 0.08, saturation: 0.92, brightness: 0.82))
        }
    }
}

// MARK: - Legacy icon property (kept for SF Symbol picker in AddEditItemView)
extension VaultCategory {
    var icon: String { primarySymbol }
}
