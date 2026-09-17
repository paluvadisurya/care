import SwiftUI

/// The violet surface every insight renders in. The sparkle animates only while something is being written,
/// and the refresh control shows its cooldown rather than silently doing nothing.
public struct InsightCardShell<Content: View>: View {
    public var title: String
    public var meta: String
    public var isGenerating: Bool
    public var canRefresh: Bool
    public var onRefresh: (() -> Void)?
    public var content: Content

    public init(title: String, meta: String, isGenerating: Bool = false, canRefresh: Bool = true,
                onRefresh: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.meta = meta
        self.isGenerating = isGenerating
        self.canRefresh = canRefresh
        self.onRefresh = onRefresh
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            header
            content
        }
        .careSurface(.intelligence)
    }

    private var header: some View {
        HStack(spacing: CareSpace.xs) {
            Image(systemName: "sparkle")
                .careSymbol(.small, weight: .bold)
                .foregroundStyle(CareColor.intelligence)
                .symbolEffect(.variableColor.iterative, isActive: isGenerating)
            Text(title)
                .careType(.labelEmphasis)
                .foregroundStyle(CareColor.intelligence)
            Spacer(minLength: CareSpace.xs)
            Text(meta)
                .careType(.meta)
                .foregroundStyle(CareColor.textMuted)
            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .careSymbol(.small)
                        .foregroundStyle(canRefresh ? CareColor.textSecondary : CareColor.textMuted)
                        .rotationEffect(.degrees(isGenerating ? 360 : 0))
                        .animation(isGenerating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                   value: isGenerating)
                        .frame(width: 30, height: 30)
                        .background(CareColor.chip, in: Circle())
                        .frame(width: CareLayout.touchTarget, height: CareLayout.touchTarget)
                        .contentShape(Circle())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .disabled(isGenerating || !canRefresh)
                .accessibilityLabel(canRefresh ? "Refresh insight" : "Refreshed recently")
            }
        }
    }
}
