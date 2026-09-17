import SwiftUI
import CareCore

/// The sizes an orb is allowed to be. Call sites pick a role, never a number, so every circle in the app
/// belongs to the same set and the space around it is reserved the same way.
public enum OrbSize: Sendable, Hashable, CaseIterable {
    /// Beside a label inside a module header.
    case inline
    /// Dense rows and pickers.
    case small
    /// The standard rail item on Today, People and the store.
    case rail
    /// A person header.
    case header
    /// The editor preview and the evening wrap.
    case hero

    public var diameter: CGFloat {
        switch self {
        case .inline: 24
        case .small: 34
        case .rail: 46
        case .header: 58
        case .hero: 72
        }
    }

    /// Space the orb reserves around the circle for its selection ring and attention dot.
    /// Exposed so a rail can compute exact item widths instead of guessing.
    public var ornamentInset: CGFloat {
        switch self {
        case .inline: 0
        case .small: 4
        case .rail, .header, .hero: 6
        }
    }

    /// The full square an orb occupies, ornaments included.
    public var reserved: CGFloat { diameter + ornamentInset * 2 }

    var selectionRingWidth: CGFloat {
        switch self {
        case .inline, .small: 2
        default: 2.5
        }
    }

    var dotDiameter: CGFloat {
        switch self {
        case .inline: 8
        case .small: 10
        default: 12
        }
    }

    var initialsRatio: CGFloat {
        switch self {
        case .inline: 0.40
        case .small: 0.38
        default: 0.355
        }
    }

    var showsShadow: Bool { self != .inline }
}

/// A person as a circle: their aura, their initials or a symbol, an optional selection ring and an optional
/// attention dot. The circle draws at `size.diameter` and the view occupies `size.reserved`, so ornaments
/// never clip and neighbours always align.
public struct PersonOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var initials: String
    public var aura: Aura
    public var size: OrbSize
    public var isSelected: Bool
    public var hasAttention: Bool
    public var symbol: String?
    public var accessibilityName: String?

    public init(initials: String, aura: Aura, size: OrbSize = .rail, isSelected: Bool = false,
                hasAttention: Bool = false, symbol: String? = nil, accessibilityName: String? = nil) {
        self.initials = initials
        self.aura = aura
        self.size = size
        self.isSelected = isSelected
        self.hasAttention = hasAttention
        self.symbol = symbol
        self.accessibilityName = accessibilityName
    }

    /// The initializer every screen should use. Derives initials, aura and the pet symbol from the record,
    /// so adding photos later changes this file and nothing else.
    public init(person: PersonRecord, size: OrbSize = .rail, isSelected: Bool = false, hasAttention: Bool = false) {
        self.init(initials: person.initials,
                  aura: person.aura,
                  size: size,
                  isSelected: isSelected,
                  hasAttention: hasAttention,
                  symbol: person.relationship == .pet ? "pawprint.fill" : nil,
                  accessibilityName: person.name)
    }

    public var body: some View {
        ZStack {
            circle
            if isSelected {
                Circle()
                    .strokeBorder(CareColor.ink, lineWidth: size.selectionRingWidth)
                    .frame(width: size.diameter + size.ornamentInset * 1.6,
                           height: size.diameter + size.ornamentInset * 1.6)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(width: size.reserved, height: size.reserved)
        .overlay(alignment: .topTrailing) {
            if hasAttention {
                AttentionDot(diameter: size.dotDiameter)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }

    private var label: String {
        let name = accessibilityName ?? initials
        return hasAttention ? "\(name), needs attention" : name
    }

    private var circle: some View {
        Circle()
            .fill(aura.gradient)
            .overlay {
                Circle().strokeBorder(.white.opacity(0.32), lineWidth: 1)
            }
            .overlay {
                // A soft top-left sheen, so the orb reads as a lit sphere rather than a flat swatch.
                Circle()
                    .fill(
                        RadialGradient(colors: [.white.opacity(0.4), .clear],
                                       center: UnitPoint(x: 0.3, y: 0.24),
                                       startRadius: 0, endRadius: size.diameter * 0.6)
                    )
                    .blendMode(.plusLighter)
            }
            .overlay { content }
            .frame(width: size.diameter, height: size.diameter)
            .shadow(color: size.showsShadow ? aura.startColor.opacity(0.32) : .clear,
                    radius: size.diameter * 0.2, y: size.diameter * 0.12)
    }

    @ViewBuilder
    private var content: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: size.diameter * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        } else {
            Text(initials)
                .font(CareFont.displayBold(size.diameter * size.initialsRatio, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
    }
}

/// Coral dot with a soft outward pulse. Solid under Reduce Motion.
public struct AttentionDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var diameter: CGFloat

    public init(diameter: CGFloat = 12) { self.diameter = diameter }

    public var body: some View {
        Circle()
            .fill(CareColor.attention)
            .frame(width: diameter, height: diameter)
            .overlay { Circle().strokeBorder(CareColor.backgroundElevated, lineWidth: diameter * 0.17) }
            .background {
                if !reduceMotion {
                    Circle()
                        .fill(CareColor.attention.opacity(0.5))
                        .phaseAnimator([1.0, 2.1]) { view, scale in
                            view.scaleEffect(scale).opacity(scale > 1.6 ? 0 : 0.55)
                        } animation: { _ in .easeOut(duration: 1.6) }
                }
            }
            .accessibilityHidden(true)
    }
}
