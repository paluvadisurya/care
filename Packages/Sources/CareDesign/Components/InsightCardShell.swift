import SwiftUI

/// The violet-bordered surface every insight renders in. Blocks come from CareModules' renderer.
public struct InsightCardShell<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    public var title: String
    public var meta: String
    public var isGenerating: Bool
    public var onRefresh: (() -> Void)?
    public var content: Content

    public init(title: String, meta: String, isGenerating: Bool = false, onRefresh: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.meta = meta
        self.isGenerating = isGenerating
        self.onRefresh = onRefresh
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            HStack(spacing: CareSpace.xs) {
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CareColor.intelligence)
                    .symbolEffect(.variableColor.iterative, isActive: isGenerating)
                Text(title)
                    .font(CareFont.labelSemi)
                    .foregroundStyle(CareColor.intelligence)
                Spacer()
                Text(meta)
                    .font(CareFont.meta)
                    .foregroundStyle(CareColor.textMuted)
                if let onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CareColor.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(CareColor.chip, in: Circle())
                    }
                    .buttonStyle(.pressable(scale: 0.9))
                    .accessibilityLabel("Refresh insight")
                    .disabled(isGenerating)
                }
            }
            content
        }
        .padding(CareSpace.md)
        .background {
            RoundedRectangle(cornerRadius: CareRadius.card)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: CareRadius.card)
                .fill(LinearGradient(colors: [CareColor.lilac.opacity(scheme == .dark ? 0.22 : 0.35), CareColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: CareRadius.card)
                .strokeBorder(CareColor.intelligence.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: CareColor.intelligence.opacity(scheme == .dark ? 0.25 : 0.18), radius: 28, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: CareRadius.card))
    }
}
