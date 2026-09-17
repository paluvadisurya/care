import SwiftUI
import CareCore
import CareDesign
import CareIntelligence
import CareData

/// The insight card as it appears on Today and on every person: loading, written, or failed, always in the
/// same frame so nothing jumps when the state changes.
public struct InsightCardView: View {
    @Environment(CareStore.self) private var store
    public var record: InsightRecord?
    public var isGenerating: Bool
    public var errorText: String?
    public var title: String
    public var now: Date
    public var onRefresh: () -> Void
    public var onAction: (DeepLink) -> Void

    public init(record: InsightRecord?, isGenerating: Bool, errorText: String? = nil, title: String = "Insight",
                now: Date = .now, onRefresh: @escaping () -> Void, onAction: @escaping (DeepLink) -> Void) {
        self.record = record
        self.isGenerating = isGenerating
        self.errorText = errorText
        self.title = title
        self.now = now
        self.onRefresh = onRefresh
        self.onAction = onAction
    }

    private var meta: String {
        guard let record else { return isGenerating ? "writing…" : "" }
        let age = CareDates.relativeShort(from: now, to: record.generatedAt)
        return record.origin == .local ? "on device · \(age)" : "refreshed \(age)"
    }

    /// The refresh control shows its cooldown rather than silently doing nothing.
    private var canRefresh: Bool {
        guard let record else { return true }
        return now.timeIntervalSince(record.generatedAt) >= InsightEngine.manualRefreshCooldown || record.origin == .local
    }

    public var body: some View {
        InsightCardShell(title: title, meta: meta, isGenerating: isGenerating, canRefresh: canRefresh, onRefresh: onRefresh) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let record {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                Text(record.insight.headline)
                    .careType(.cardTitle)
                    .foregroundStyle(CareColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                InsightBlocksView(blocks: record.insight.blocks, now: now, onAction: onAction)

                HStack(alignment: .firstTextBaseline, spacing: CareSpace.xs) {
                    if let note = record.refreshNote {
                        Text(note)
                            .careType(.meta)
                            .foregroundStyle(CareColor.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    FeedbackButtons(current: record.feedback) { feedback in
                        store.setFeedback(feedback, for: record.id)
                    }
                }
            }
            .id(record.generatedAt)
            .transition(.opacity)
        } else if isGenerating {
            InsightSkeleton()
        } else if let errorText {
            ErrorState(title: "Could not write an insight", message: errorText, retry: onRefresh)
        } else {
            Text("Log a few things and an insight will appear here.")
                .careType(.callout)
                .foregroundStyle(CareColor.textSecondary)
        }
    }
}

struct FeedbackButtons: View {
    var current: InsightFeedback?
    var onSet: (InsightFeedback?) -> Void

    var body: some View {
        HStack(spacing: 2) {
            button(.up, "hand.thumbsup", "Helpful")
            button(.down, "hand.thumbsdown", "Not helpful")
        }
    }

    private func button(_ feedback: InsightFeedback, _ symbol: String, _ label: String) -> some View {
        let isOn = current == feedback
        return Button {
            onSet(isOn ? nil : feedback)
        } label: {
            Image(systemName: isOn ? symbol + ".fill" : symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? CareColor.intelligence : CareColor.textMuted)
                .symbolEffect(.bounce, value: isOn)
                .frame(width: 30, height: 30)
                .background(CareColor.chip, in: Circle())
                .frame(width: CareLayout.touchTarget, height: CareLayout.touchTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.pressable(scale: 0.88))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
