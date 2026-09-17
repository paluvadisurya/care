import SwiftUI
import CareCore

/// Structured-style day rail. Time labels on the left, aura-coloured dots on a hairline, cards on the right,
/// and a "now" marker that moves on its own.
public struct TimelineRail: View {
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

    private var rows: [Row] {
        var out: [Row] = items.map { .item($0) }
        // Insert the now marker at the right spot if today.
        if let first = items.first, Calendar.care.isDate(first.start, inSameDayAs: now) {
            let idx = items.firstIndex { !$0.isAllDay && $0.start > now } ?? items.count
            out.insert(.now, at: idx)
        }
        return out
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

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                switch row {
                case .item(let item):
                    TimelineRow(item: item, aura: auraFor(item.personID), isPast: !item.isAllDay && item.start < now, onTap: { onTap(item) })
                case .now:
                    NowMarker()
                }
            }
        }
    }
}

struct TimelineRow: View {
    var item: TimelineItem
    var aura: Aura?
    var isPast: Bool
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: CareSpace.xs) {
            Text(item.isAllDay ? "all day" : CareDates.timeLabel(item.start))
                .font(CareFont.monoMedium(11, relativeTo: .caption2))
                .foregroundStyle(CareColor.textMuted)
                .frame(width: 52, alignment: .trailing)
                .padding(.top, 14)
            ZStack(alignment: .top) {
                Rectangle().fill(CareColor.separator).frame(width: 2)
                Circle()
                    .fill(aura?.gradient ?? LinearGradient(colors: [CareColor.ink, CareColor.ink], startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: 14)
                    .overlay { Circle().strokeBorder(CareColor.backgroundElevated, lineWidth: 2) }
                    .padding(.top, 14)
            }
            .frame(width: 16)
            Button(action: onTap) {
                HStack(spacing: CareSpace.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(CareFont.textSemi(15, relativeTo: .body))
                            .foregroundStyle(CareColor.textPrimary)
                            .strikethrough(item.isDone, color: CareColor.textMuted)
                        Text(item.subtitle)
                            .font(CareFont.caption)
                            .foregroundStyle(CareColor.textMuted)
                    }
                    Spacer(minLength: 0)
                    SourceTag(source: item.source, tone: item.tone, isDone: item.isDone)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .careCard(radius: CareRadius.inner + 4, padding: CareSpace.sm)
                .opacity(isPast && !item.isDone ? 0.75 : 1)
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
                Image(systemName: "checkmark.circle.fill").foregroundStyle(CareColor.positive)
            } else {
                Text(label)
                    .font(CareFont.meta)
                    .foregroundStyle(tone == .attention ? CareColor.attention : CareColor.textMuted)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(CareColor.chip, in: Capsule())
            }
        }
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
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            HStack(spacing: CareSpace.xs) {
                Text(CareDates.timeLabel(ctx.date))
                    .font(CareFont.monoMedium(11, relativeTo: .caption2))
                    .foregroundStyle(CareColor.attention)
                    .frame(width: 52, alignment: .trailing)
                Circle()
                    .fill(CareColor.backgroundElevated)
                    .overlay { Circle().strokeBorder(CareColor.attention, lineWidth: 3) }
                    .frame(width: 14, height: 14)
                    .frame(width: 16)
                Rectangle().fill(CareColor.attention).frame(height: 1.5)
            }
            .padding(.vertical, CareSpace.xs)
            .accessibilityLabel("Now")
        }
    }
}
