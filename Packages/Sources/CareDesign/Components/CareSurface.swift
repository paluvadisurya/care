import SwiftUI

/// Every card in Care is one of these. A variant decides fill, border, radius, padding and elevation together,
/// so a screen never sets four properties that could drift apart.
public enum CareSurfaceVariant: Sendable, Hashable {
    /// Standard card. Glass over the mesh.
    case card
    /// The one hero per screen. Larger radius, stronger fill, more padding.
    case hero
    /// A tile in a grid. Smaller radius and padding.
    case tile
    /// A row in a list.
    case row
    /// Something that needs you. Coral ring and glow, never a red fill.
    case attention
    /// An insight. Violet border and glow.
    case intelligence
    /// A field or inline control. Flat, bordered, no shadow.
    case field

    var radius: CGFloat {
        switch self {
        case .hero, .attention: CareRadius.hero
        case .card, .intelligence: CareRadius.card
        case .tile, .row: CareRadius.tile
        case .field: CareRadius.inner
        }
    }

    var padding: CGFloat {
        switch self {
        case .hero, .attention: CareSpace.md + 2
        case .card, .intelligence: CareSpace.md
        case .tile: CareSpace.sm + 2
        case .row: CareSpace.sm
        case .field: CareSpace.sm
        }
    }

    var elevation: CareElevation {
        switch self {
        case .hero: .lifted
        case .card, .tile, .row: .resting
        case .attention: .attention
        case .intelligence: .intelligence
        case .field: .flat
        }
    }

    var borderColor: Color {
        switch self {
        case .attention: CareColor.attention.opacity(0.65)
        case .intelligence: CareColor.intelligence.opacity(0.45)
        default: CareColor.separator
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .attention: 1.5
        default: 1
        }
    }

    /// Strong surfaces sit above the mesh rather than letting it read through.
    var isStrong: Bool {
        switch self {
        case .hero, .attention, .field: true
        default: false
        }
    }
}

public struct CareSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public var variant: CareSurfaceVariant
    public var padding: CGFloat?

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: variant.radius)
        content
            .padding(padding ?? variant.padding)
            .background {
                if reduceTransparency {
                    shape.fill(CareColor.backgroundElevated)
                } else {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(variant.isStrong ? CareColor.surfaceStrong : CareColor.surface)
                    if variant == .intelligence {
                        shape.fill(
                            LinearGradient(
                                colors: [CareColor.lilac.opacity(0.28), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    }
                }
            }
            .overlay { shape.strokeBorder(variant.borderColor, lineWidth: variant.borderWidth) }
            .clipShape(shape)
            .careElevation(variant.elevation)
    }
}

public extension View {
    /// The one way a card is drawn.
    func careSurface(_ variant: CareSurfaceVariant = .card, padding: CGFloat? = nil) -> some View {
        modifier(CareSurfaceModifier(variant: variant, padding: padding))
    }
}
