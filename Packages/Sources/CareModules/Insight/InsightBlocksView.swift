import SwiftUI
import CareCore
import CareDesign
import CareIntelligence

/// Maps every block type to a view. Blocks enter staggered by 80 ms.
public struct InsightBlocksView: View {
    public var blocks: [InsightBlock]
    public var now: Date
    public var onAction: (DeepLink) -> Void

    public init(blocks: [InsightBlock], now: Date = .now, onAction: @escaping (DeepLink) -> Void) {
        self.blocks = blocks
        self.now = now
        self.onAction = onAction
    }

    private var stats: [InsightBlock] { blocks.filter { if case .stat = $0 { return true } else { return false } } }
    private var rest: [InsightBlock] { blocks.filter { if case .stat = $0 { return false } else { return true } } }

    public var body: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            if !stats.isEmpty {
                HStack(spacing: CareSpace.xs) {
                    ForEach(Array(stats.prefix(3).enumerated()), id: \.offset) { i, block in
                        if case .stat(let label, let value, let trend, let tone) = block {
                            StatTile(label: label, value: value, trend: trend, tone: tone)
                                .staggeredEntrance(index: i)
                        }
                    }
                }
            }
            ForEach(Array(rest.enumerated()), id: \.offset) { i, block in
                blockView(block)
                    .staggeredEntrance(index: i + min(stats.count, 3))
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: InsightBlock) -> some View {
        switch block {
        case .stat(let label, let value, let trend, let tone):
            StatTile(label: label, value: value, trend: trend, tone: tone)
        case .trend(let label, let points, let annotation):
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
                Sparkline(points: points, color: CareColor.violet, height: 52)
                if let annotation { Text(annotation).font(CareFont.caption).foregroundStyle(CareColor.textMuted) }
            }
            .padding(CareSpace.sm)
            .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner + 2))
        case .countdown(let title, let dateString):
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
                    if let date = Self.parse(dateString) {
                        Countdown(to: date, now: now, size: 40, showHours: false)
                    } else {
                        Text(dateString).font(CareFont.tileValue)
                    }
                }
                Spacer()
                if let date = Self.parse(dateString) {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                }
            }
            .padding(CareSpace.sm)
            .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner + 2))
        case .list(let title, let items):
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(CareColor.violet).frame(width: 5, height: 5).padding(.top, 6)
                        Text(item.text).font(CareFont.callout).foregroundStyle(CareColor.textPrimary)
                    }
                }
            }
        case .action(let title, let reason, let deeplink):
            Button {
                if let link = DeepLink(string: deeplink) { onAction(link) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(CareFont.textSemi(15, relativeTo: .body)).foregroundStyle(CareColor.inkText)
                        Text(reason).font(CareFont.caption).foregroundStyle(CareColor.inkText.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold)).foregroundStyle(CareColor.inkText)
                }
                .padding(CareSpace.sm)
                .background(CareColor.ink, in: RoundedRectangle(cornerRadius: CareRadius.inner + 2))
            }
            .buttonStyle(.pressable)
        case .insight(let text, _):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkle").font(.system(size: 11, weight: .bold)).foregroundStyle(CareColor.violet).padding(.top, 4)
                Text(text).font(CareFont.callout).foregroundStyle(CareColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
        case .moodStrip(let label, let values):
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
                MoodStrip(values: values, height: 30)
            }
        case .talkingPoints(let items):
            VStack(alignment: .leading, spacing: 6) {
                Text("Talking points").font(CareFont.label).foregroundStyle(CareColor.textSecondary)
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1)").font(CareFont.monoMedium(11)).foregroundStyle(CareColor.violet).frame(width: 14)
                        Text(item).font(CareFont.callout).foregroundStyle(CareColor.textPrimary)
                    }
                }
            }
        case .compare(let label, let aLabel, let a, let bLabel, let b):
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(CareFont.label).foregroundStyle(CareColor.textSecondary)
                CompareBars(aLabel: aLabel, a: a, bLabel: bLabel, b: b)
            }
        case .note(let text):
            Text(text).font(CareFont.meta).foregroundStyle(CareColor.textMuted).fixedSize(horizontal: false, vertical: true)
        case .unknown:
            EmptyView()
        }
    }

    static func parse(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: String(s.prefix(10))) { return d }
        return ISO8601DateFormatter().date(from: s)
    }
}

struct StatTile: View {
    var label: String
    var value: String
    var trend: TrendDirection?
    var tone: StatTone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(CareFont.caption).foregroundStyle(CareColor.textSecondary).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(CareFont.displayBold(22, relativeTo: .title2)).numeralStyle(22).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
                if let trend {
                    Image(systemName: trend == .up ? "arrow.up.right" : trend == .down ? "arrow.down.right" : "arrow.right")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CareSpace.sm)
        .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner + 2))
    }

    var color: Color {
        switch tone {
        case .good: CareColor.positive
        case .attention: CareColor.attention
        case .neutral: CareColor.textPrimary
        }
    }
}

struct CompareBars: View {
    var aLabel: String
    var a: Double
    var bLabel: String
    var b: Double

    var body: some View {
        let maxV = max(a, b, 1)
        VStack(spacing: 6) {
            bar(label: aLabel, value: a, fraction: a / maxV, color: CareColor.violet)
            bar(label: bLabel, value: b, fraction: b / maxV, color: CareColor.lilac)
        }
    }

    func bar(label: String, value: Double, fraction: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(CareFont.caption).foregroundStyle(CareColor.textSecondary).frame(width: 84, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                Capsule().fill(color).frame(width: max(8, geo.size.width * fraction))
            }
            .frame(height: 10)
            Text(value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value))
                .font(CareFont.monoMedium(11)).foregroundStyle(CareColor.textPrimary).frame(width: 36, alignment: .trailing)
        }
    }
}
