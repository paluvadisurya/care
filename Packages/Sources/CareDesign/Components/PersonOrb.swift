import SwiftUI
import CareCore

/// A 44 pt avatar with the person's aura, an optional selection ring and a pulsing coral attention dot.
public struct PersonOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var initials: String
    public var aura: Aura
    public var size: CGFloat
    public var isSelected: Bool
    public var hasAttention: Bool
    public var symbol: String?

    public init(initials: String, aura: Aura, size: CGFloat = CareRadius.orb, isSelected: Bool = false, hasAttention: Bool = false, symbol: String? = nil) {
        self.initials = initials
        self.aura = aura
        self.size = size
        self.isSelected = isSelected
        self.hasAttention = hasAttention
        self.symbol = symbol
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(aura.gradient)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }
                .overlay {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: size * 0.42, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(initials)
                            .font(CareFont.displayBold(size * 0.36, relativeTo: .headline))
                            .foregroundStyle(.white)
                            .tracking(-0.5)
                    }
                }
                .shadow(color: aura.startColor.opacity(0.35), radius: 10, y: 6)
                .frame(width: size, height: size)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(CareColor.ink, lineWidth: 2.5)
                            .padding(-4)
                    }
                }
            if hasAttention {
                AttentionDot()
                    .offset(x: 2, y: -2)
            }
        }
        .frame(width: size + 8, height: size + 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(hasAttention ? "\(initials), needs attention" : initials))
    }
}

/// Coral dot with a soft pulse. Solid under Reduce Motion.
public struct AttentionDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}

    public var body: some View {
        Circle()
            .fill(CareColor.attention)
            .frame(width: 12, height: 12)
            .overlay { Circle().strokeBorder(CareColor.backgroundElevated, lineWidth: 2) }
            .background {
                if !reduceMotion {
                    Circle()
                        .fill(CareColor.attention.opacity(0.5))
                        .phaseAnimator([1.0, 1.9]) { view, scale in
                            view.scaleEffect(scale).opacity(scale > 1.5 ? 0 : 0.6)
                        } animation: { _ in .easeOut(duration: 1.4) }
                }
            }
    }
}
