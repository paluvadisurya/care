import SwiftUI
import CareCore

/// One module on a profile or on Today. Sizes 1x1 and 2x1. Shows today's state and an optional ring or trail.
public struct BentoTile: View {
    public var title: String
    public var symbol: String
    public var state: ModuleTodayState
    public var accent: Color
    public var wide: Bool

    public init(title: String, symbol: String, state: ModuleTodayState, accent: Color = CareColor.violet, wide: Bool = false) {
        self.title = title
        self.symbol = symbol
        self.state = state
        self.accent = accent
        self.wide = wide
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(CareFont.label)
                    .foregroundStyle(CareColor.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if state.needsAttention { AttentionDot().scaleEffect(0.85) }
            }
            HStack(alignment: .center, spacing: CareSpace.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.headline)
                        .font(CareFont.tileValue)
                        .displayTracking(22)
                        .foregroundStyle(state.tone == .attention ? CareColor.attention : CareColor.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text(state.detail)
                        .font(CareFont.caption)
                        .foregroundStyle(CareColor.textMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if let p = state.progress {
                    Ring(progress: p, size: 46, lineWidth: 6, gradient: [accent, accent.opacity(0.6)])
                }
            }
            if !state.trail.isEmpty {
                MoodStrip(values: state.trail, height: 22)
            }
        }
        .frame(maxWidth: .infinity, minHeight: wide ? 96 : 108, alignment: .topLeading)
        .careCard(radius: CareRadius.tile, padding: CareSpace.sm + 2)
    }
}
