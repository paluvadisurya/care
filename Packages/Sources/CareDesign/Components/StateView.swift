import SwiftUI
import CareCore

/// Calm empty state. One symbol, one line, one question, one button. Never guilty, never a dead end.
public struct EmptyState: View {
    public var symbol: String
    public var title: String
    public var message: String
    public var buttonTitle: String?
    public var aura: Aura?
    public var action: (() -> Void)?

    public init(symbol: String, title: String, message: String, buttonTitle: String? = nil,
                aura: Aura? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.aura = aura
        self.action = action
    }

    public var body: some View {
        VStack(spacing: CareSpace.sm) {
            ZStack {
                Circle()
                    .fill(aura?.gradient ?? LinearGradient(colors: [CareColor.chip, CareColor.chip], startPoint: .top, endPoint: .bottom))
                    .opacity(aura == nil ? 1 : 0.18)
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(aura?.startColor ?? CareColor.textSecondary)
            }
            .frame(width: 64, height: 64)

            VStack(spacing: CareSpace.xxs) {
                Text(title)
                    .careType(.cardTitle)
                    .foregroundStyle(CareColor.textPrimary)
                Text(message)
                    .careType(.callout)
                    .foregroundStyle(CareColor.textSecondary)
            }
            .multilineTextAlignment(.center)

            if let buttonTitle, let action {
                PillButton(buttonTitle, style: .ghost, compact: true, action: action)
                    .padding(.top, CareSpace.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CareSpace.lg)
        .padding(.horizontal, CareSpace.md)
        .accessibilityElement(children: .combine)
    }
}

/// Violet shimmer placeholder while an insight generates. Never blocks the rest of the screen.
public struct SkeletonBlock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var height: CGFloat
    public var delay: Double

    public init(height: CGFloat = 18, delay: Double = 0) {
        self.height = height
        self.delay = delay
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: CareRadius.small)
            .fill(CareColor.intelligence.opacity(0.14))
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                        let period = 1.7
                        let t = (ctx.date.timeIntervalSinceReferenceDate - delay).truncatingRemainder(dividingBy: period) / period
                        LinearGradient(colors: [.clear, CareColor.lilac.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 150)
                            .offset(x: -220 + CGFloat(t) * 560)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CareRadius.small))
            .accessibilityHidden(true)
    }
}

/// The shape an insight takes while it is being written. Matches the real card's rhythm so nothing jumps
/// when the content arrives.
public struct InsightSkeleton: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            SkeletonBlock(height: 24, delay: 0)
            HStack(spacing: CareSpace.xs) {
                SkeletonBlock(height: 58, delay: 0.1)
                SkeletonBlock(height: 58, delay: 0.2)
            }
            SkeletonBlock(height: 16, delay: 0.3)
        }
        .accessibilityLabel("Writing an insight")
    }
}

/// A plain failure with one way out. Used wherever a network call can fail.
public struct ErrorState: View {
    public var title: String
    public var message: String
    public var retryTitle: String
    public var retry: () -> Void

    public init(title: String, message: String, retryTitle: String = "Try again", retry: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retry = retry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            Text(title)
                .careType(.bodyEmphasis)
                .foregroundStyle(CareColor.textPrimary)
            Text(message)
                .careType(.caption)
                .foregroundStyle(CareColor.textMuted)
            PillButton(retryTitle, symbol: "arrow.clockwise", style: .ghost, compact: true, action: retry)
                .padding(.top, CareSpace.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
