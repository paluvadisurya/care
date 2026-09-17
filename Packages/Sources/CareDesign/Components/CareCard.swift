import SwiftUI

/// The quiet glass surface every card sits on. White at 72 percent over ultra-thin material in light, 7 percent white at night.
/// One hairline border for structure; a soft shadow for elevation in light only.
public struct CareCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public var radius: CGFloat
    public var padding: CGFloat
    public var attention: Bool
    public var strong: Bool

    public func body(content: Content) -> some View {
        let shadow = CareShadow.card(scheme)
        let shape = RoundedRectangle(cornerRadius: radius)
        content
            .padding(padding)
            .background {
                if reduceTransparency {
                    shape.fill(CareColor.backgroundElevated)
                } else {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(strong ? CareColor.surfaceStrong : CareColor.surface)
                }
            }
            .overlay {
                shape.strokeBorder(attention ? CareColor.attention.opacity(0.7) : CareColor.separator, lineWidth: attention ? 1.5 : 1)
            }
            .shadow(color: attention ? CareColor.attention.opacity(0.18) : shadow.color, radius: attention ? 24 : shadow.radius, y: attention ? 10 : shadow.y)
            .clipShape(shape)
    }
}

public extension View {
    func careCard(radius: CGFloat = CareRadius.card, padding: CGFloat = CareSpace.md, attention: Bool = false, strong: Bool = false) -> some View {
        modifier(CareCardModifier(radius: radius, padding: padding, attention: attention, strong: strong))
    }
}

/// Section label above a group of cards. Sentence case, never all caps.
public struct SectionLabel: View {
    public var title: String
    public var trailing: String?

    public init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CareFont.labelSemi)
                .foregroundStyle(CareColor.textSecondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(CareFont.meta)
                    .foregroundStyle(CareColor.textMuted)
            }
        }
        .padding(.horizontal, CareSpace.xxs)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Calm empty state: the aura, one question, one button. Never guilty.
public struct EmptyState: View {
    public var symbol: String
    public var title: String
    public var message: String
    public var buttonTitle: String?
    public var action: (() -> Void)?

    public init(symbol: String, title: String, message: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: CareSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(CareColor.textSecondary)
                .padding(CareSpace.md)
                .background(CareColor.chip, in: Circle())
            Text(title)
                .font(CareFont.cardTitle)
                .foregroundStyle(CareColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(CareFont.callout)
                .foregroundStyle(CareColor.textSecondary)
                .multilineTextAlignment(.center)
            if let buttonTitle, let action {
                PillButton(buttonTitle, style: .ghost, action: action)
                    .padding(.top, CareSpace.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(CareSpace.lg)
    }
}

/// Violet shimmer placeholder used while an insight generates. Never blocks the rest of the screen.
public struct SkeletonBlock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var height: CGFloat

    public init(height: CGFloat = 18) { self.height = height }

    public var body: some View {
        RoundedRectangle(cornerRadius: CareRadius.small)
            .fill(CareColor.violet.opacity(0.14))
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
                        LinearGradient(colors: [.clear, CareColor.lilac.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 140)
                            .offset(x: -200 + CGFloat(t) * 500)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CareRadius.small))
                }
            }
            .accessibilityHidden(true)
    }
}
