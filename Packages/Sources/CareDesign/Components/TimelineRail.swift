import SwiftUI
import CareCore

/// The day rail. Time labels on the left, aura-coloured dots on a hairline, cards on the right, and a
/// "now" marker that moves on its own.
///
/// The time column scales with Dynamic Type instead of sitting at a fixed width, so times never clip.
public struct TimelineRail: View {
    @ScaledMetric(relativeTo: .caption2) private var timeColumn: CGFloat = 54
    public var items: [TimelineItem]
    public var now: Date
    public var auraFor: (UUID?) -> Aura?
    public var onTap: (TimelineItem) -> Void

    public init(items: [TimelineItem], now: Date, auraFor: @escaping (UUID?) -> Aura?, onTap: @escaping (TimelineItem) -> Void) {
        self.items = items
        self.now = now
        self.auraFor = auraFor
        self.onTap = onTap
    }

    enum Row: Identifiable {
        case item(TimelineItem)
        case now

        var id: String {
            switch self {
            case .item(let i): i.id
            case .now: "now"
            }
        }
    }

    private var rows: [Row] {
        var out: [Row] = items.map { .item($0) }
        if let first = items.first, Calendar.care.isDate(first.start, inSameDayAs: now) {
            let index = items.firstIndex { !$0.isAllDay && $0.start > now } ?? items.count
            out.insert(.now, at: index)
        }
        return out
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                switch row {
                case .item(let item):
                    TimelineRow(item: item, aura: auraFor(item.personID), now: now,
                                timeColumn: timeColumn) { onTap(item) }
                case .now:
                    NowMarker(timeColumn: timeColumn)
                }
            }
        }
    }
}

struct TimelineRow: View {
    var item: TimelineItem
    var aura: Aura?
    var now: Date
    var timeColumn: CGFloat
    var onTap: () -> Void

    private var isPast: Bool { !item.isAllDay && item.start < now }

    var body: some View {
        HStack(alignment: .top, spacing: CareSpace.xs) {
            Text(item.isAllDay ? "all day" : CareDates.timeLabel(item.start))
                .careType(.metaEmphasis)
                .foregroundStyle(CareColor.textMuted)
                .frame(width: timeColumn, alignment: .trailing)
                .padding(.top, 15)

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(CareColor.separator)
                    .frame(width: 2)
                Circle()
                    .fill(aura?.gradient ?? LinearGradient(colors: [CareColor.ink, CareColor.ink], startPoint: .top, endPoint: .bottom))
                    .frame(width: 13, height: 13)
                    .overlay { Circle().strokeBorder(CareColor.backgroundElevated, lineWidth: 2.5) }
                    .padding(.top, 14)
            }
            .frame(width: 16)

            Button(action: onTap) {
                HStack(spacing: CareSpace.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .careType(.bodyEmphasis)
                            .foregroundStyle(CareColor.textPrimary)
                            .strikethrough(item.isDone, color: CareColor.textMuted)
                            .lineLimit(2)
                        Text(item.subtitle)
                            .careType(.caption)
                            .foregroundStyle(CareColor.textMuted)
                    }
                    Spacer(minLength: 0)
                    SourceTag(source: item.source, tone: item.tone, isDone: item.isDone)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .careSurface(.row)
                .opacity(isPast && !item.isDone ? 0.72 : 1)
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
        .padding(.bottom, CareSpace.xs)
    }
}

struct SourceTag: View {
    var source: TimelineItem.Source
    var tone: Tone
    var isDone: Bool

    var body: some View {
        Group {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(CareColor.positive)
                    .font(.system(size: 18))
            } else {
                Text(label)
                    .careType(.meta)
                    .foregroundStyle(tone == .attention ? CareColor.attention : CareColor.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tone == .attention ? CareColor.attention.opacity(0.12) : CareColor.chip, in: Capsule())
            }
        }
        .accessibilityHidden(true)
    }

    var label: String {
        switch source {
        case .care: "Care"
        case .appleCalendar: "Calendar"
        case .appleReminders: "Reminders"
        }
    }
}

struct NowMarker: View {
    var timeColumn: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            HStack(spacing: CareSpace.xs) {
                Text(CareDates.timeLabel(ctx.date))
                    .careType(.metaEmphasis)
                    .foregroundStyle(CareColor.attention)
                    .frame(width: timeColumn, alignment: .trailing)
                Circle()
                    .fill(CareColor.backgroundElevated)
                    .overlay { Circle().strokeBorder(CareColor.attention, lineWidth: 3) }
                    .frame(width: 13, height: 13)
                    .frame(width: 16)
                Rectangle()
                    .fill(LinearGradient(colors: [CareColor.attention, CareColor.attention.opacity(0.15)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1.5)
            }
            .padding(.vertical, CareSpace.xs)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Now")
        }
    }
}
