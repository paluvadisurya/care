import Foundation

public struct CallRhythmSettings: Codable, Hashable, Sendable {
    public var weekday: Int          // 1 = Sunday ... 7 = Saturday (Calendar.weekday)
    public var hour: Int
    public var cadenceDays: Int
    public init(weekday: Int = 1, hour: Int = 18, cadenceDays: Int = 7) {
        self.weekday = weekday
        self.hour = hour
        self.cadenceDays = cadenceDays
    }
    public var weekdayName: String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[max(0, min(6, weekday - 1))]
    }
}

public struct CallPayload: Codable, Hashable, Sendable {
    public var durationMinutes: Int?
    public var note: String?
    public var talkingPoints: [String]
    public init(durationMinutes: Int? = nil, note: String? = nil, talkingPoints: [String] = []) {
        self.durationMinutes = durationMinutes
        self.note = note
        self.talkingPoints = talkingPoints
    }
}

public enum CallRhythmLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.callRhythm)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .talkingPoints, .action, .insight, .note]
    public static let reminderRules = [
        ReminderRule(id: "call.rhythm", kind: .callRhythm, description: "Rhythm day at the preferred time, with talking points"),
    ]

    public static func settings(_ ctx: ModuleContext) -> CallRhythmSettings {
        ctx.person.settings(CallRhythmSettings.self, for: .callRhythm) ?? CallRhythmSettings()
    }

    public static func isRhythmDay(_ ctx: ModuleContext) -> Bool {
        ctx.calendar.component(.weekday, from: ctx.now) == settings(ctx).weekday
    }

    public static func calledToday(_ ctx: ModuleContext) -> Bool { !ctx.todayEntries.isEmpty }

    public static func talkingPoints(_ ctx: ModuleContext) -> [String] {
        var points = MentionsLogic.talkingPoints(from: ctx.allEntries, limit: 2)
        let soon = ctx.events.filter { $0.moduleID != .dates && $0.start > ctx.now && CareDates.daysBetween(ctx.now, $0.start, calendar: ctx.calendar) <= 7 }
        if let e = soon.first { points.append("\(e.title) \(CareDates.relativeDays(from: ctx.now, to: e.start))") }
        if let city = ctx.person.homeCity, points.count < 3 { points.append("How is the weather in \(city)?") }
        return Array(points.prefix(3))
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        let s = settings(ctx)
        let gap = ModuleHelpers.daysSinceLast(ctx.entries, now: ctx.now, calendar: ctx.calendar)
        if isRhythmDay(ctx) {
            return ModuleTodayState(headline: calledToday(ctx) ? "Called" : "\(s.weekdayName) call", detail: calledToday(ctx) ? "Done for this week" : "\(ModuleHelpers.plural(talkingPoints(ctx).count, "talking point")) ready",
                                    tone: calledToday(ctx) ? .positive : .upcoming, needsAttention: !calledToday(ctx))
        }
        return ModuleTodayState(headline: "Every \(s.weekdayName)", detail: gap.map { "Last call \($0 == 0 ? "today" : "\($0)d ago")" } ?? "No calls yet",
                                tone: (gap ?? 0) > s.cadenceDays + 2 ? .attention : .neutral)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        let s = settings(ctx)
        var out: [Signal] = []
        let gap = ModuleHelpers.daysSinceLast(ctx.entries, now: ctx.now, calendar: ctx.calendar) ?? 99
        if isRhythmDay(ctx), !calledToday(ctx) {
            let points = talkingPoints(ctx)
            out.append(Signal(
                id: ModuleHelpers.signalID(.callRhythm, .callRhythm, p.id), personID: p.id, moduleID: .callRhythm, kind: .callRhythm,
                title: "\(s.weekdayName). \(p.shortName) day", body: points.isEmpty ? "Your usual call." : "Ask about: " + points.joined(separator: " · "),
                at: CareDates.at(hour: s.hour, on: ctx.now, calendar: ctx.calendar), priority: 0.5, tone: .upcoming, hero: .word("Call day"),
                actions: [SignalAction(title: "Call \(p.shortName)", kind: .call, link: .module(personID: p.id, module: .callRhythm), isPrimary: true),
                          SignalAction(title: "Later", kind: .remindLater, link: .module(personID: p.id, module: .callRhythm))]))
        } else if gap > s.cadenceDays + 2 {
            out.append(Signal(
                id: ModuleHelpers.signalID(.callRhythm, .quietWeek, p.id), personID: p.id, moduleID: .callRhythm, kind: .quietWeek,
                title: "\(p.shortName). \(gap) days since a call", body: "The \(s.weekdayName) rhythm slipped. A short call counts.",
                priority: 0.4, tone: .attention,
                actions: [SignalAction(title: "Call \(p.shortName)", kind: .call, link: .module(personID: p.id, module: .callRhythm), isPrimary: true)]))
        }
        return out
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let calls = ctx.entries(in: window)
        let s = settings(ctx)
        let data: JSONValue = .object([
            "rhythm": .string("every \(s.weekdayName) \(s.hour):00"), "calls": .int(calls.count),
            "last_call": calls.first.map { .date($0.occurredAt) } ?? .null,
            "days_since": ModuleHelpers.daysSinceLast(ctx.entries, now: ctx.now, calendar: ctx.calendar).map { .int($0) } ?? .null,
            "talking_points": .array(talkingPoints(ctx).map { .string($0) }),
        ])
        return ContextPack(moduleID: .callRhythm, summary: "\(calls.count) calls in window", data: data)
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let p = ctx.person
        let s = settings(ctx)
        guard isRhythmDay(ctx), !calledToday(ctx) else { return [] }
        let points = talkingPoints(ctx)
        return [ReminderCandidate(
            id: "call.\(p.id.uuidString.prefix(8)).\(CareDates.isoDay(ctx.now))", personID: p.id, moduleID: .callRhythm, kind: .callRhythm,
            earliest: CareDates.at(hour: s.hour, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: min(21, s.hour + 2), on: ctx.now, calendar: ctx.calendar),
            priority: 0.55, message: "\(s.weekdayName). \(p.shortName) day. \(points.isEmpty ? "" : "\(points.count) things to ask about inside.")", reason: "Call rhythm",
            actions: [ReminderAction(id: "call", title: "Call"), ReminderAction(id: "later", title: "Later")],
            link: .module(personID: p.id, module: .callRhythm))]
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        let s = settings(ctx)
        guard ctx.calendar.component(.weekday, from: day) == s.weekday else { return [] }
        let done = ctx.entries.contains { ctx.calendar.isDate($0.occurredAt, inSameDayAs: day) }
        return [TimelineItem(id: "call.\(ctx.person.id.uuidString.prefix(8)).\(CareDates.isoDay(day))", personID: ctx.person.id, moduleID: .callRhythm,
                             title: "Call \(ctx.person.shortName)", subtitle: "\(s.weekdayName) rhythm · \(ModuleHelpers.plural(talkingPoints(ctx).count, "talking point"))",
                             start: CareDates.at(hour: s.hour, on: day, calendar: ctx.calendar), tone: done ? .positive : .upcoming,
                             link: .module(personID: ctx.person.id, module: .callRhythm), isDone: done)]
    }
}
