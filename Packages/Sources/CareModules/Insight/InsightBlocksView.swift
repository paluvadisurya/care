import SwiftUI
import CareCore
import CareDesign
import CareIntelligence

/// Maps every block the model can return to a view. Stats gather into one row, everything else stacks, and
/// the whole set enters on a stagger so an insight assembles itself rather than appearing all at once.
public struct InsightBlocksView: View {
    public var blocks: [InsightBlock]
    public var now: Date
    public var onAction: (DeepLink) -> Void

    public init(blocks: [InsightBlock], now: Date = .now, onAction: @escaping (DeepLink) -> Void) {
        self.blocks = blocks
        self.now = now
        self.onAction = onAction
    }

    private var stats: [InsightBlock] {
        blocks.filter { if case .stat = $0 { true } else { false } }
    }

    private var rest: [InsightBlock] {
        blocks.filter { if case .stat = $0 { false } else { true } }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            if !stats.isEmpty {
                HStack(alignment: .top, spacing: CareSpace.xs) {
                    ForEach(Array(stats.prefix(3).enumerated()), id: \.offset) { index, block in
                        if case .stat(let label, let value, let trend, let tone) = block {
                            StatTile(label: label, value: value, trend: trend, tone: tone)
                                .staggeredEntrance(index: index)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(rest.enumerated()), id: \.offset) { index, block in
                view(for: block)
                    .staggeredEntrance(index: index + min(stats.count, 3))
            }
        }
    }

    @ViewBuilder
    private func view(for block: InsightBlock) -> some View {
        switch block {
        case .stat(let label, let value, let trend, let tone):
            StatTile(label: label, value: value, trend: trend, tone: tone)

        case .trend(let label, let points, let annotation):
            BlockPanel(label: label) {
                Sparkline(points: points, color: CareColor.intelligence, height: 54)
                if let annotation {
                    Text(annotation)
                        .careType(.caption)
                        .foregroundStyle(CareColor.textMuted)
                }
            }

        case .countdown(let title, let dateString):
            BlockPanel(label: title) {
                HStack(alignment: .firstTextBaseline) {
                    if let date = Self.parse(dateString) {
                        Countdown(to: date, now: now, size: .large, showsHours: false)
                        Spacer(minLength: CareSpace.xs)
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                            .careType(.meta)
                            .foregroundStyle(CareColor.textMuted)
                    } else {
                        Text(dateString).careType(.tileValue)
                    }
                }
            }

        case .list(let title, let items):
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .careType(.label)
                    .foregroundStyle(CareColor.textSecondary)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: CareSpace.xs) {
                        Circle()
                            .fill(CareColor.intelligence)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 3 }
                        Text(item.text)
                            .careType(.callout)
                            .foregroundStyle(CareColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .action(let title, let reason, let deeplink):
            Button {
                if let link = DeepLink(string: deeplink) { onAction(link) }
            } label: {
                HStack(spacing: CareSpace.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .careType(.bodyEmphasis)
                            .foregroundStyle(CareColor.inkText)
                        Text(reason)
                            .careType(.caption)
                            .foregroundStyle(CareColor.inkText.opacity(0.66))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(CareColor.inkText)
                }
                .padding(CareSpace.sm)
                .frame(minHeight: CareLayout.touchTarget)
                .background(CareColor.ink, in: RoundedRectangle(cornerRadius: CareRadius.inner))
                .contentShape(RoundedRectangle(cornerRadius: CareRadius.inner))
            }
            .buttonStyle(.pressable)

        case .insight(let text, _):
            HStack(alignment: .firstTextBaseline, spacing: CareSpace.xs) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(CareColor.intelligence)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                Text(text)
                    .careType(.callout)
                    .foregroundStyle(CareColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .moodStrip(let label, let values):
            BlockPanel(label: label) {
                MoodStrip(values: values, height: 30)
            }

        case .talkingPoints(let items):
            VStack(alignment: .leading, spacing: 6) {
                Text("Talking points")
                    .careType(.label)
                    .foregroundStyle(CareColor.textSecondary)
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: CareSpace.xs) {
                        Text("\(index + 1)")
                            .careType(.metaEmphasis)
                            .foregroundStyle(CareColor.intelligence)
                            .frame(width: 14, alignment: .leading)
                        Text(item)
                            .careType(.callout)
                            .foregroundStyle(CareColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .compare(let label, let aLabel, let a, let bLabel, let b):
            BlockPanel(label: label) {
                CompareBars(aLabel: aLabel, a: a, bLabel: bLabel, b: b)
            }

        case .note(let text):
            Text(text)
                .careType(.footnote)
                .foregroundStyle(CareColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)

        case .unknown:
            EmptyView()
        }
    }

    static func parse(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: String(string.prefix(10))) { return date }
        return ISO8601DateFormatter().date(from: string)
    }
}

/// The quiet panel that holds a chart, a strip or a pair of bars inside an insight.
private struct BlockPanel<Content: View>: View {
    var label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .careType(.label)
                .foregroundStyle(CareColor.textSecondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CareSpace.sm)
        .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
    }
}

/// One number in the stat row of an insight.
///
/// The label sits at the top and the value is pinned to the bottom, so a label that wraps to two lines
/// grows the whole row and every value in it still lands on one baseline. Three stats with labels of
/// wildly different lengths read as one instrument rather than three loose readouts.
struct StatTile: View {
    @ScaledMetric(relativeTo: .headline) private var minHeight: CGFloat = 66
    var label: String
    var value: String
    var trend: TrendDirection?
    var tone: StatTone

    private var color: Color {
        switch tone {
        case .good: CareColor.positive
        case .attention: CareColor.attention
        case .neutral: CareColor.textPrimary
        }
    }

    private var trendSymbol: String? {
        switch trend {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        case nil: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.xs) {
            Text(label)
                .careType(.caption)
                .foregroundStyle(CareColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .careType(.tileValue)
                    .foregroundStyle(color)
                    .rollingNumber()
                if let trendSymbol {
                    Image(systemName: trendSymbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
        .padding(CareSpace.sm)
        .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
        .accessibilityElement(children: .combine)
    }
}

struct CompareBars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var aLabel: String
    var a: Double
    var bLabel: String
    var b: Double

    var body: some View {
        let maximum = max(a, b, 1)
        VStack(spacing: 6) {
            bar(label: aLabel, value: a, fraction: a / maximum, color: CareColor.intelligence)
            bar(label: bLabel, value: b, fraction: b / maximum, color: CareColor.lilac)
        }
    }

    private func bar(label: String, value: Double, fraction: Double, color: Color) -> some View {
        HStack(spacing: CareSpace.xs) {
            Text(label)
                .careType(.caption)
                .foregroundStyle(CareColor.textSecondary)
                .frame(width: 86, alignment: .leading)
            GeometryReader { geometry in
                Capsule()
                    .fill(color)
                    .frame(width: max(8, geometry.size.width * fraction))
                    .animation(CareMotion.standard(reduced: reduceMotion), value: fraction)
            }
            .frame(height: 10)
            Text(value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value))
                .careType(.metaEmphasis)
                .foregroundStyle(CareColor.textPrimary)
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
