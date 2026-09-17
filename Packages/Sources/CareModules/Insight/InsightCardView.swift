import SwiftUI
import CareCore
import CareDesign
import CareIntelligence
import CareData

/// The insight card as it appears on Today and on every person. Handles loading, error and feedback.
public struct InsightCardView: View {
    @Environment(CareStore.self) private var store
    public var record: InsightRecord?
    public var isGenerating: Bool
    public var errorText: String?
    public var title: String
    public var now: Date
    public var onRefresh: () -> Void
    public var onAction: (DeepLink) -> Void

    public init(record: InsightRecord?, isGenerating: Bool, errorText: String? = nil, title: String = "Insight", now: Date = .now,
                onRefresh: @escaping () -> Void, onAction: @escaping (DeepLink) -> Void) {
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

    public var body: some View {
        InsightCardShell(title: title, meta: meta, isGenerating: isGenerating, onRefresh: onRefresh) {
            if let record {
                VStack(alignment: .leading, spacing: CareSpace.sm) {
                    Text(record.insight.headline)
                        .font(CareFont.displayBold(21, relativeTo: .title3))
                        .displayTracking(21)
                        .foregroundStyle(CareColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    InsightBlocksView(blocks: record.insight.blocks, now: now, onAction: onAction)
                    HStack {
                        if let note = record.refreshNote {
                            Text(note).font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                        }
                        Spacer()
                        FeedbackButtons(current: record.feedback) { fb in
                            store.setFeedback(fb, for: record.id)
                        }
                    }
                }
                .id(record.generatedAt)
            } else if isGenerating {
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBlock(height: 22)
                    HStack { SkeletonBlock(height: 54); SkeletonBlock(height: 54) }
                    SkeletonBlock(height: 16)
                }
            } else if let errorText {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Could not write an insight").font(CareFont.bodyMedium).foregroundStyle(CareColor.textPrimary)
                    Text(errorText).font(CareFont.caption).foregroundStyle(CareColor.textMuted)
                    PillButton("Try again", style: .ghost, compact: true, action: onRefresh)
                }
            } else {
                Text("Log a few things and an insight will appear here.")
                    .font(CareFont.callout).foregroundStyle(CareColor.textSecondary)
            }
        }
    }
}

struct FeedbackButtons: View {
    var current: InsightFeedback?
    var onSet: (InsightFeedback?) -> Void

    var body: some View {
        HStack(spacing: 4) {
            button(.up, "hand.thumbsup")
            button(.down, "hand.thumbsdown")
        }
    }

    func button(_ fb: InsightFeedback, _ symbol: String) -> some View {
        Button {
            onSet(current == fb ? nil : fb)
        } label: {
            Image(systemName: current == fb ? symbol + ".fill" : symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(current == fb ? CareColor.violet : CareColor.textMuted)
                .frame(width: 30, height: 30)
                .background(CareColor.chip, in: Circle())
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(fb == .up ? "Helpful" : "Not helpful")
    }
}
