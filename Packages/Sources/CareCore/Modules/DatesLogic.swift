import Foundation

/// A gift given for a date, so nothing repeats.
public struct GiftPayload: Codable, Hashable, Sendable {
    public var eventID: UUID
    public var year: Int
    public var gift: String
    public init(eventID: UUID, year: Int, gift: String) {
        self.eventID = eventID
        self.year = year
        self.gift = gift
    }
}

public enum DatesLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.dates)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .countdown, .list, .action, .insight, .note]
    public static let reminderRules = [
        ReminderRule(id: "dates.lead", kind: .date, description: "14 days, 3 days and the morning of"),
    ]

    public struct Upcoming: Hashable, Sendable {
        public var event: EventRecord
        public var date: Date
        public var days: Int
        public var years: Int?
    }

    public static func upcoming(_ ctx: ModuleContext, within days: Int = 366) -> [Upcoming] {
        ctx.events(for: .dates).compactMap { e in
            let next = e.nextOccurrence(after: ctx.now, calendar: ctx.calendar)
            let d = CareDates.daysBetween(ctx.now, next, calendar: ctx.calendar)
            guard d >= 0, d <= days else { return nil }
            return Upcoming(event: e, date: next, days: d, years: e.yearsAt(ctx.now, calendar: ctx.calendar))
        }.sorted { $0.days < $1.days }
    }

    public static func lastGift(for event: EventRecord, _ ctx: ModuleContext) -> GiftPayload? {
        ctx.entries.compactMap { $0.decode(GiftPayload.self) }.filter { $0.eventID == event.id }.max { $0.year < $1.year }
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        guard let next = upcoming(ctx).first else {
            return ModuleTodayState(headline: "No dates", detail: "Add a birthday")
        }
        let headline = next.days == 0 ? "Today" : "\(next.days)d"
        var detail = next.event.title
        if let y = next.years, y > 0 { detail += " · \(ordinal(y))" }
        return ModuleTodayState(headline: headline, detail: detail, tone: next.days <= 3 ? .upcoming : .neutral)
    }

    public static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        return upcoming(ctx, within: 14).map { u in
            let gift = lastGift(for: u.event, ctx)
            var body = u.days == 0 ? "Today." : "In \(ModuleHelpers.plural(u.days, "day"))."
            if let y = u.years, y > 0 { body += " The \(ordinal(y))." }
            if let gift { body += " Last year: \(gift.gift)." }
            return Signal(
                id: ModuleHelpers.signalID(.dates, .dateSoon, p.id, suffix: u.event.id.uuidString.prefix(6).description),
                personID: p.id, moduleID: .dates, kind: .dateSoon,
                title: "\(p.shortName). \(u.event.title)", body: body, at: u.date,
                priority: 0.45 + Double(14 - u.days) / 14 * 0.3, tone: .upcoming, hero: .countdown(u.date),
                actions: [SignalAction(title: "Plan", link: .module(personID: p.id, module: .dates), isPrimary: true),
                          SignalAction(title: "Wishlist", link: .module(personID: p.id, module: .wishlist))])
        }
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let rows = upcoming(ctx, within: 90).map { u -> JSONValue in
            .object(["id": .string(u.event.id.uuidString), "title": .string(u.event.title), "date": .date(u.date),
                     "days": .int(u.days), "years": u.years.map { .int($0) } ?? .null,
                     "last_gift": .optional(lastGift(for: u.event, ctx)?.gift)])
        }
        guard !rows.isEmpty else { return nil }
        return ContextPack(moduleID: .dates, summary: "\(rows.count) dates in 90 days", data: .array(rows))
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let p = ctx.person
        return upcoming(ctx, within: 14).compactMap { u in
            guard [14, 3, 0].contains(u.days) else { return nil }
            let gift = lastGift(for: u.event, ctx)
            let message = u.days == 0 ? "\(u.event.title) is today." : "\(u.event.title) in \(u.days) days.\(gift.map { " Last year: \($0.gift)." } ?? "")"
            return ReminderCandidate(
                id: "dates.\(u.event.id.uuidString.prefix(8)).\(u.days)", personID: p.id, moduleID: .dates, kind: .date,
                earliest: CareDates.at(hour: 9, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 11, on: ctx.now, calendar: ctx.calendar),
                priority: u.days == 0 ? 0.7 : 0.5, message: message, reason: "Lead time for \(u.event.category.displayName.lowercased())",
                actions: [ReminderAction(id: "plan", title: "Plan", link: .module(personID: p.id, module: .dates)),
                          ReminderAction(id: "wishlist", title: "Wishlist", link: .module(personID: p.id, module: .wishlist))],
                link: .module(personID: p.id, module: .dates))
        }
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        ctx.events(for: .dates).compactMap { e in
            let next = e.nextOccurrence(after: ctx.calendar.startOfDay(for: day), calendar: ctx.calendar)
            guard ctx.calendar.isDate(next, inSameDayAs: day) else { return nil }
            let years = e.yearsAt(day, calendar: ctx.calendar)
            return TimelineItem(id: "date.\(e.id.uuidString.prefix(8))", personID: ctx.person.id, moduleID: .dates, title: e.title,
                                subtitle: years.map { $0 > 0 ? "\(ctx.person.shortName) · the \(ordinal($0))" : ctx.person.shortName } ?? ctx.person.shortName,
                                start: next, isAllDay: true, tone: .upcoming, link: .module(personID: ctx.person.id, module: .dates))
        }
    }
}
