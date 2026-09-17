import SwiftUI
import CareCore

/// Semantic colours. Light and night variants live in the asset catalogue so the system switches them.
/// Roles stay fixed: coral means attention, violet intelligence, mint done, amber upcoming.
public enum CareColor {
    public static let background = Color("careBackground", bundle: .module)
    public static let backgroundElevated = Color("careBackgroundElevated", bundle: .module)
    public static let surface = Color("careSurface", bundle: .module)
    public static let surfaceStrong = Color("careSurfaceStrong", bundle: .module)
    public static let textPrimary = Color("careTextPrimary", bundle: .module)
    public static let textSecondary = Color("careTextSecondary", bundle: .module)
    public static let textMuted = Color("careTextMuted", bundle: .module)
    public static let separator = Color("careSeparator", bundle: .module)
    public static let ink = Color("careInk", bundle: .module)
    public static let inkText = Color("careInkText", bundle: .module)
    public static let chip = Color("careChip", bundle: .module)

    public static let coral = Color("careCoral", bundle: .module)
    public static let rose = Color("careRose", bundle: .module)
    public static let violet = Color("careViolet", bundle: .module)
    public static let lilac = Color("careLilac", bundle: .module)
    public static let amber = Color("careAmber", bundle: .module)
    public static let mint = Color("careMint", bundle: .module)
    public static let sky = Color("careSky", bundle: .module)
    public static let peach = Color("carePeach", bundle: .module)
    public static let honey = Color("careHoney", bundle: .module)

    // Semantic roles
    public static let attention = coral
    public static let intelligence = violet
    public static let positive = mint
    public static let upcoming = amber

    public static func tone(_ tone: Tone) -> Color {
        switch tone {
        case .attention: attention
        case .upcoming: upcoming
        case .positive: positive
        case .neutral: textSecondary
        }
    }
}

public extension Color {
    /// Parses "#RRGGBB" or "#RRGGBBAA". Used for auras, which are stored as hex strings.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255; g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255; a = Double(value & 0xFF) / 255
        default:
            r = Double((value >> 16) & 0xFF) / 255; g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

public extension Aura {
    var startColor: Color { Color(hex: start) }
    var endColor: Color { Color(hex: end) }

    var gradient: LinearGradient {
        LinearGradient(colors: [startColor, endColor], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var angularGradient: AngularGradient {
        AngularGradient(colors: [startColor, endColor, startColor], center: .center)
    }
}
