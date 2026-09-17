import Foundation

public struct MoodPayload: Codable, Hashable, Sendable {
    public var value: Int          // 1 low ... 5 great
    public var energy: Int?        // 1 ... 5, optional vertical axis
    public var tag: String?        // "work", "sleep", "family"
    public var note: String?

    public init(value: Int, energy: Int? = nil, tag: String? = nil, note: String? = nil) {
        self.value = value
        self.energy = energy
        self.tag = tag
        self.note = note
    }

    public static let tags = ["work", "sleep", "family", "health", "money", "friends", "weather", "travel"]
}

public enum MoodLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.mood)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .trend, .list, .action, .insight, .moodStrip, .note]
    public static let reminderRules = [
        ReminderRule(id: "mood.pulse", kind: .pulseCheck, description: "A three-face check when there has been no check-in for two days"),
        ReminderRule(id: "mood.low", kind: .signal, description: "Three low days in a row"),
    ]

    public static func value(_ e: EntryRecord) -> Int? { e.decode(MoodPayload.self)?.value }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        let trail = ModuleHelpers.trail(ctx.entries, days: 14, now: ctx.now, calendar: ctx.calendar, value: value)
        if let today = ctx.todayEntries.first, let v = value(today) {
            return ModuleTodayState(headline: ModuleHelpers.moodWord(v),
                                    detail: "Checked in \(CareDates.relativeShort(from: ctx.now, to: today.occurredAt))",
                                    tone: v <= 2 ? .attention : (v >= 4 ? .positive : .neutral), trail: trail)
        }
        if let last = ctx.entries.first, let v = value(last) {
            return ModuleTodayState(headline: ModuleHelpers.moodWord(v),
                                    detail: "Last \(CareDates.relativeShort(from: ctx.now, to: last.occurredAt))",
                                    tone: .neutral, trail: trail, needsAttention: false)
        }
        return ModuleTodayState(headline: "How are they?", detail: "No check-in yet", trail: trail)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        var out: [Signal] = []
        let p = ctx.person
        let low = ModuleHelpers.streak(ctx.entries, now: ctx.now, calendar: ctx.calendar) { (value($0) ?? 3) <= 2 }
        if low >= 3 {
            out.append(Signal(
                id: ModuleHelpers.signalID(.mood, .lowStreak, p.id), personID: p.id, moduleID: .mood, kind: .lowStreak,
                title: "\(p.shortName). Low for \(low) days", body: "Three low days in a row. A quiet check-in might help.",
                at: nil, priority: 0.7, tone: .attention, hero: .word("Low ×\(low)"),
                actions: [SignalAction(title: "Check in", kind: .log, link: .quickSheet(personID: p.id), isPrimary: true),
                          SignalAction(title: "Open", link: .module(personID: p.id, module: .mood))]))
        }
        if p.relationship != .pet, let gap = ModuleHelpers.daysSinceLast(ctx.entries, now: ctx.now, calendar: ctx.calendar), gap >= 2 {
            out.append(Signal(
                id: ModuleHelpers.signalID(.mood, .checkInDue, p.id), personID: p.id, moduleID: .mood, kind: .checkInDue,
                title: "How is \(p.shortName)?", body: "No check-in for \(gap) days.",
                priority: 0.3, tone: .neutral,
                actions: [SignalAction(title: "Check in", kind: .log, link: .quickSheet(personID: p.id), isPrimary: true)]))
        } else if ctx.entries.isEmpty, p.relationship != .pet {
            out.append(Signal(
                id: ModuleHelpers.signalID(.mood, .checkInDue, p.id), personID: p.id, moduleID: .mood, kind: .checkInDue,
                title: "How is \(p.shortName)?", body: "First check-in. One drag on the Pulse.",
                priority: 0.25, tone: .neutral,
                actions: [SignalAction(title: "Check in", kind: .log, link: .quickSheet(personID: p.id), isPrimary: true)]))
        }
        return out
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let entries = ctx.entries(in: window)
        guard !entries.isEmpty else { return nil }
        func row(_ e: EntryRecord) -> JSONValue {
            let p = e.decode(MoodPayload.self)
            return .object(["id": .string(e.id.uuidString), "d": .string(CareDates.shortDay(e.occurredAt)),
                            "v": .int(p?.value ?? 3), "tag": .optional(p?.tag)])
        }
        let selfRows = entries.filter { $0.author == .selfReport }.map(row)
        let observed = entries.filter { $0.author == .observed }.map(row)
        let avg = ModuleHelpers.weekdayAverages(entries, calendar: ctx.calendar, value: value)
        let low = entries.filter { (value($0) ?? 3) <= 2 }.count
        let data: JSONValue = .object([
            "self": .array(selfRows), "observed": .array(observed),
            "weekday_avg": .object(avg.mapValues { .number($0) }),
            "checkins": .int(entries.count), "low_days": .int(low),
            "trail_14": .array(ModuleHelpers.trail(ctx.entries, days: 14, now: ctx.now, calendar: ctx.calendar, value: value)
                                .map { $0.map { JSONValue.int($0) } ?? .null }),
        ])
        return ContextPack(moduleID: .mood, summary: "\(entries.count) check-ins, \(low) low days",
                           data: data, evidenceIDs: entries.map { $0.id.uuidString })
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        var out: [ReminderCandidate] = []
        let p = ctx.person
        guard p.relationship != .pet else { return out }
        let gap = ModuleHelpers.daysSinceLast(ctx.entries, now: ctx.now, calendar: ctx.calendar) ?? 99
        if gap >= 2 {
            let day = CareDates.hour(of: ctx.now, calendar: ctx.calendar) >= 20 ? CareDates.adding(days: 1, to: ctx.now, calendar: ctx.calendar) : ctx.now
            out.append(ReminderCandidate(
                id: "mood.pulse.\(p.id.uuidString.prefix(8)).\(CareDates.isoDay(day))", personID: p.id, moduleID: .mood, kind: .pulseCheck,
                earliest: CareDates.at(hour: 10, on: day, calendar: ctx.calendar), latest: CareDates.at(hour: 19, on: day, calendar: ctx.calendar),
                priority: 0.4, message: "How is \(p.shortName) today?", reason: "No check-in for \(gap) days",
                actions: [ReminderAction(id: "mood.5", title: "😊"), ReminderAction(id: "mood.3", title: "😐"), ReminderAction(id: "mood.1", title: "😞")],
                link: .quickSheet(personID: p.id)))
        }
        return out
    }
}
