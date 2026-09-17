import SwiftUI

/// Spacing scale: 4, 8, 12, 16, 24, 32. Section gaps are at least twice the gap inside a section.
public enum CareSpace {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48

    /// Horizontal screen gutter.
    public static let gutter: CGFloat = 20
    /// Space above the floating tab bar so the last card clears it.
    public static let tabBarClearance: CGFloat = 112
}

/// Radii follow the concentric rule: outer = inner + padding.
public enum CareRadius {
    public static let hero: CGFloat = 28
    public static let card: CGFloat = 24
    public static let tile: CGFloat = 20
    public static let inner: CGFloat = 12
    public static let small: CGFloat = 10
    public static let pill: CGFloat = 999
    public static let orb: CGFloat = 44
}

public enum CareShadow {
    /// Cards: soft, low, wide. None at night; glass carries the depth.
    public static func card(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        scheme == .dark ? (.clear, 0, 0) : (Color.black.opacity(0.06), 24, 8)
    }
}
