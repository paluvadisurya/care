import Foundation

public enum EventOutcome: String, Codable, CaseIterable, Sendable, Hashable {
    case wentWell, okay, hard
    public var label: String {
        switch self {
        case .wentWell: "Went well"
        case .okay: "Okay"
        case .hard: "Hard"
        }
    }
}

/// The answer to "how did it go?" stored as an entry in the Events module.
public struct EventFollowUpPayload: Codable, Hashable, Sendable {
    public var eventID: UUID
    public var outcome: EventOutcome
    public var note: String?
    public init(eventID: UUID, outcome: EventOutcome, note: String? = nil) {
        self.eventID = eventID
        self.outcome = outcome
        self.note = note
    }
}

public enum EventsLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.events)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .countdown, .list, .action, .insight, .note]
    public static let reminderRules = [
        ReminderRule(id: "events.before", kind: .eventBefore, description: "Lead time set by the category"),
        ReminderRule(id: "events.after", kind: .eventAfter, description: "How did it go, one hour after it ends"),
    ]

    public static func followUp(for event: EventRecord, _ ctx: ModuleContext) -> EventFollowUpPayload? {
        ctx.entries.compactMap { $0.decode(EventFollowUpPayload.self) }.first { $0.eventID == event.id }
    }

    public static func upcoming(_ ctx: ModuleContext, days: Int) -> [EventRecord] {
        let limit = CareDates.adding(days: days, to: ctx.now, calendar: ctx.calendar)
        return ctx.events(for: .events).filter { $0.start >= ctx.calendar.startOfDay(for: ctx.now) && $0.start <= limit }
            .sorted { $0.start < $1.start }
    }

    public static func awaitingFollowUp(_ ctx: ModuleContext) -> [EventRecord] {
        ctx.events(for: .events).filter { e in
            guard e.followUp else { return false }
            let end = e.end ?? CareDates.adding(hours: 1, to: e.start, calendar: ctx.calendar)
            let hours = ctx.now.timeIntervalSince(end) / 3600
            return hours >= 0 && hours <= 48 && followUp(for: e, ctx) == nil
        }
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        if let e = awaitingFollowUp(ctx).first {
            return ModuleTodayState(headline: "How did it go?", detail: e.title, tone: .upcoming, needsAttention: true)
        }
        guard let next = upcoming(ctx, days: 30).first else {
            return ModuleTodayState(headline: "Nothing ahead", detail: "Add an event")
        }
        let d = CareDates.daysBetween(ctx.now, next.start, calendar: ctx.calendar)
        return ModuleTodayState(headline: d == 0 ? CareDates.timeLabel(next.start, calendar: ctx.calendar) : "\(d)d",
                                detail: next.title, tone: d <= 1 ? .upcoming : .neutral)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        var out: [Signal] = []
        for e in upcoming(ctx, days: 1) where e.start > ctx.now {
            let action = e.category.defaults.suggestedAction
            out.append(Signal(
                id: ModuleHelpers.signalID(.events, .eventSoon, p.id, suffix: e.id.uuidString.prefix(6).description),
                personID: p.id, moduleID: .events, kind: .eventSoon,
                title: "\(p.shortName). \(e.title)", body: e.supportNote ?? action, at: e.start,
                priority: e.category == .health ? 0.65 : 0.55, tone: .upcoming, hero: .countdown(e.start),
                actions: [SignalAction(title: "Message", kind: .message, link: .person(p.id), isPrimary: true),
                          SignalAction(title: "Remind after", kind: .remindLater, link: .module(personID: p.id, module: .events))]))
        }
        for e in awaitingFollowUp(ctx) {
            out.append(Signal(
                id: ModuleHelpers.signalID(.events, .eventFollowUp, p.id, suffix: e.id.uuidString.prefix(6).description),
                personID: p.id, moduleID: .events, kind: .eventFollowUp,
                title: "\(p.shortName). \(e.title) finished", body: "Ask how it went.", at: e.end ?? e.start,
                priority: 0.5, tone: .upcoming, hero: .word("How did it go?"),
                actions: EventOutcome.allCases.map {
                    SignalAction(title: $0.label, kind: .log, link: .newEntry(personID: p.id, module: .events, title: "\(e.id.uuidString)|\($0.rawValue)"), isPrimary: $0 == .wentWell)
                }))
        }
        return out
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let ahead = upcoming(ctx, days: 14).map { e -> JSONValue in
            .object(["id": .string(e.id.uuidString), "title": .string(e.title), "cat": .string(e.category.rawValue),
                     "date": .date(e.start), "followup": .bool(e.followUp)])
        }
        let outcomes = ctx.entries(in: window).compactMap { e -> JSONValue? in
            guard let f = e.decode(EventFollowUpPayload.self) else { return nil }
            let title = ctx.events.first { $0.id == f.eventID }?.title ?? "event"
            return .object(["title": .string(title), "outcome": .string(f.outcome.rawValue), "d": .string(CareDates.shortDay(e.occurredAt))])
        }
        guard !ahead.isEmpty || !outcomes.isEmpty else { return nil }
        return ContextPack(moduleID: .events, summary: "\(ahead.count) events ahead, \(outcomes.count) follow-ups",
                           data: .object(["upcoming": .array(ahead), "outcomes": .array(outcomes)]))
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let p = ctx.person
        var out: [ReminderCandidate] = []
        for e in upcoming(ctx, days: 15) {
            let days = CareDates.daysBetween(ctx.now, e.start, calendar: ctx.calendar)
            if e.leadTimes.contains(days), days > 0 {
                out.append(ReminderCandidate(
                    id: "events.before.\(e.id.uuidString.prefix(8)).\(days)", personID: p.id, moduleID: .events, kind: .eventBefore,
                    earliest: CareDates.at(hour: 18, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 21, on: ctx.now, calendar: ctx.calendar),
                    priority: 0.45, message: "\(p.shortName)'s \(e.title) is \(days == 1 ? "tomorrow" : "in \(days) days").",
                    reason: e.category.defaults.suggestedAction,
                    actions: [ReminderAction(id: "message", title: "Message"), ReminderAction(id: "done", title: "Done")],
                    link: .module(personID: p.id, module: .events)))
            }
            if days == 0 {
                let before: Date
                switch e.category.defaults.dayOf {
                case .morning: before = CareDates.at(hour: 8, on: e.start, calendar: ctx.calendar)
                case .twoHoursBefore: before = CareDates.adding(hours: -2, to: e.start, calendar: ctx.calendar)
                case .oneHourBefore: before = CareDates.adding(hours: -1, to: e.start, calendar: ctx.calendar)
                case .atStart: before = e.start
                }
                if before > ctx.now {
                    out.append(ReminderCandidate(
                        id: "events.dayof.\(e.id.uuidString.prefix(8))", personID: p.id, moduleID: .events, kind: .eventBefore,
                        earliest: before, latest: e.start, priority: 0.6,
                        message: "\(p.shortName)'s \(e.title) at \(CareDates.timeLabel(e.start, calendar: ctx.calendar)).",
                        reason: e.category.defaults.suggestedAction,
                        actions: [ReminderAction(id: "message", title: "Message"), ReminderAction(id: "done", title: "Done")],
                        link: .module(personID: p.id, module: .events)))
                }
            }
        }
        for e in awaitingFollowUp(ctx) {
            let end = e.end ?? CareDates.adding(hours: 1, to: e.start, calendar: ctx.calendar)
            out.append(ReminderCandidate(
                id: "events.after.\(e.id.uuidString.prefix(8))", personID: p.id, moduleID: .events, kind: .eventAfter,
                earliest: CareDates.adding(hours: 1, to: end, calendar: ctx.calendar), latest: CareDates.adding(hours: 6, to: end, calendar: ctx.calendar),
                priority: 0.55, message: "\(p.shortName)'s \(e.title) finished. How did it go?", reason: "Follow-up for \(e.category.displayName.lowercased())",
                actions: EventOutcome.allCases.map { ReminderAction(id: "outcome.\($0.rawValue)", title: $0.label) },
                link: .module(personID: p.id, module: .events)))
        }
        return out
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        ctx.events(for: .events).filter { ctx.calendar.isDate($0.start, inSameDayAs: day) }.map { e in
            TimelineItem(id: "event.\(e.id.uuidString.prefix(8))", personID: ctx.person.id, moduleID: .events, title: e.title,
                         subtitle: "\(ctx.person.shortName) · \(e.category.displayName)", start: e.start, end: e.end,
                         isAllDay: e.isAllDay, source: e.source == .importCalendar ? .appleCalendar : .care,
                         tone: e.category == .health ? .attention : .neutral,
                         link: .module(personID: ctx.person.id, module: .events), isDone: followUp(for: e, ctx) != nil)
        }
    }
}
