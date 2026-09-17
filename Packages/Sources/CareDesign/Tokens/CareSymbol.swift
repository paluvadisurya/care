import SwiftUI

/// Symbol sizes, as roles.
///
/// Eleven different SF Symbol sizes were being passed at call sites, from 9 to 24, which is the same drift
/// the type ramp was built to stop. Worse, `Font.system(size:)` does not respond to Dynamic Type at all, so
/// every symbol in the app stayed put while the text around it grew. A role fixes both: five steps, and a
/// size that scales with the reader's setting.
public nonisolated enum CareSymbol: Sendable, Hashable, CaseIterable {
    /// A mark inside another mark: a chevron on a chip, a caret on a field.
    case tiny
    /// Beside a label: the insight sparkle, a tile glyph, a trailing chevron.
    case small
    /// A row glyph or a button's leading symbol.
    case medium
    /// A tab bar item, a hero card's leading symbol, an add button.
    case large
    /// A control that is mostly symbol: a checkbox, an empty state's mark.
    case xlarge

    public var size: CGFloat {
        switch self {
        case .tiny: 10
        case .small: 12.5
        case .medium: 15
        case .large: 17.5
        case .xlarge: 23
        }
    }
}

public extension View {
    /// The only way a symbol is sized. Scales with Dynamic Type, unlike a raw `Font.system(size:)`.
    func careSymbol(_ role: CareSymbol, weight: Font.Weight = .semibold) -> some View {
        modifier(CareSymbolModifier(role: role, weight: weight))
    }
}

public struct CareSymbolModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var unit: CGFloat = 1
    public var role: CareSymbol
    public var weight: Font.Weight

    public init(role: CareSymbol, weight: Font.Weight) {
        self.role = role
        self.weight = weight
    }

    public func body(content: Content) -> some View {
        content.font(.system(size: role.size * unit, weight: weight))
    }
}
