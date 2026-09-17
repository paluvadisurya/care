import SwiftUI

/// The spacing scale. Four point steps, named by weight rather than by pixel count.
/// A section gap is always at least twice the gap inside a section, which is what gives the app its rhythm.
public enum CareSpace {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48

    /// Horizontal screen gutter. Everything that touches the edge of a screen uses this and nothing else.
    public static let gutter: CGFloat = 20
    /// Space above the floating tab bar so the last card clears it.
    public static let tabBarClearance: CGFloat = CareLayout.scrollBottomInset
}

/// Layout metrics. Screens compose from these instead of inventing numbers.
public enum CareLayout {
    /// Gap between two sections of a screen.
    public static let sectionGap: CGFloat = 26
    /// Gap between cards inside one section.
    public static let stackGap: CGFloat = 12
    /// Gutter between grid tiles. Matches `stackGap` so vertical and horizontal rhythm agree.
    public static let tileGap: CGFloat = 12
    /// Gap between items in a horizontal rail.
    public static let railGap: CGFloat = 10

    /// The floating tab bar.
    public static let tabBarHeight: CGFloat = 62
    public static let tabBarBottomInset: CGFloat = 10
    /// Bottom inset for any scroll view that sits behind the tab bar.
    public static var scrollBottomInset: CGFloat { tabBarHeight + tabBarBottomInset + sectionGap }
    /// Bottom inset for a screen with a floating primary action instead of the tab bar.
    public static let actionBottomInset: CGFloat = 96

    /// Minimum interactive target. Controls may draw smaller but must reserve this.
    public static let touchTarget: CGFloat = 44

    /// Height of the aura wash behind a person header.
    public static let auraWashHeight: CGFloat = 280
}

/// Radii follow the concentric rule: an inner radius equals its outer radius minus the padding between them,
/// so nested corners stay optically parallel instead of drifting.
public enum CareRadius {
    public static let hero: CGFloat = 28
    public static let card: CGFloat = 24
    public static let tile: CGFloat = 20
    public static let inner: CGFloat = 14
    public static let small: CGFloat = 10
    public static let pill: CGFloat = 999

    /// The radius a child should use when it sits `padding` inside a parent of `outer`.
    public static func concentric(outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(small, outer - padding)
    }
}

/// Elevation levels. Light mode carries depth with shadow, night mode carries it with glass and border,
/// so the same level reads correctly in both without a call site ever checking the colour scheme.
public enum CareElevation: Sendable, Hashable {
    /// Flat against the background. Chips, inline fields.
    case flat
    /// Resting surface. Tiles and rows.
    case resting
    /// Lifted surface. The hero card, sheets.
    case lifted
    /// Intelligence surfaces, which glow violet rather than casting a shadow.
    case intelligence
    /// Attention surfaces, which glow coral.
    case attention

    func shadow(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        let night = scheme == .dark
        switch self {
        case .flat:
            return (.clear, 0, 0)
        case .resting:
            return night ? (.black.opacity(0.35), 16, 6) : (.black.opacity(0.05), 18, 6)
        case .lifted:
            return night ? (.black.opacity(0.5), 30, 14) : (.black.opacity(0.08), 30, 12)
        case .intelligence:
            return (CareColor.intelligence.opacity(night ? 0.3 : 0.18), 28, 10)
        case .attention:
            return (CareColor.attention.opacity(night ? 0.3 : 0.16), 24, 10)
        }
    }
}

public extension View {
    func careElevation(_ level: CareElevation) -> some View {
        modifier(CareElevationModifier(level: level))
    }
}

public struct CareElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    public var level: CareElevation

    public func body(content: Content) -> some View {
        let s = level.shadow(scheme)
        return content.shadow(color: s.color, radius: s.radius, y: s.y)
    }
}
