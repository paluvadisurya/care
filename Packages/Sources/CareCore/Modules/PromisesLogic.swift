import Foundation

public struct PromisePayload: Codable, Hashable, Sendable {
    public var text: String
    public var due: Date?
    public var kept: Bool
    public var keptAt: Date?
    public init(text: String, due: Date? = nil, kept: Bool = false, keptAt: Date? = nil) {
        self.text = text
        self.due = due
        self.kept = kept
        self.keptAt = keptAt
    }
}

public enum PromisesLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.promises)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .list, .action, .note]
    public static let reminderRules = [
        ReminderRule(id: "promises.due", kind: .promise, description: "Due date, then a soft weekly nudge"),
    ]

    public static func open(_ ctx: ModuleContext) -> [(EntryRecord, PromisePayload)] {
        ctx.entries.compactMap { e -> (EntryRecord, PromisePayload)? in
            guard let promise = e.decode(PromisePayload.self), !promise.kept else { return nil }
            return (e, promise)
        }
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        let open = open(ctx)
        guard let first = open.first else { return ModuleTodayState(headline: "All kept", detail: "Nothing open", tone: .positive) }
        return ModuleTodayState(headline: "\(open.count) open", detail: first.1.text, tone: first.1.due.map { $0 < ctx.now ? .attention : .neutral } ?? .neutral)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        var out: [Signal] = []
        for (e, promise) in open(ctx) {
            if let due = promise.due, CareDates.daysBetween(ctx.now, due, calendar: ctx.calendar) <= 1 {
                out.append(Signal(id: ModuleHelpers.signalID(.promises, .promiseDue, p.id, suffix: e.id.uuidString.prefix(6).description), personID: p.id, moduleID: .promises, kind: .promiseDue,
                                  title: "You promised \(p.shortName)", body: "\(promise.text). \(due < ctx.now ? "Past due." : "Due \(CareDates.relativeDays(from: ctx.now, to: due)).")",
                                  at: due, priority: 0.5, tone: .upcoming, hero: .word("Promise"),
                                  actions: [SignalAction(title: "Kept it", kind: .done, link: .module(personID: p.id, module: .promises), isPrimary: true)]))
            } else if CareDates.daysBetween(e.occurredAt, ctx.now, calendar: ctx.calendar) >= 14, CareDates.daysBetween(e.occurredAt, ctx.now, calendar: ctx.calendar) % 7 == 0 {
                out.append(Signal(id: ModuleHelpers.signalID(.promises, .promiseStale, p.id, suffix: e.id.uuidString.prefix(6).description), personID: p.id, moduleID: .promises, kind: .promiseStale,
                                  title: "Still open for \(p.shortName)", body: "\(promise.text). \(CareDates.daysBetween(e.occurredAt, ctx.now, calendar: ctx.calendar)) days.",
                                  priority: 0.25, tone: .neutral,
                                  actions: [SignalAction(title: "Open", link: .module(personID: p.id, module: .promises), isPrimary: true)]))
            }
        }
        return out
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let open = open(ctx)
        guard !open.isEmpty else { return nil }
        let rows = open.map { JSONValue.object(["id": .string($0.0.id.uuidString), "t": .string($0.1.text), "age_days": .int(CareDates.daysBetween($0.0.occurredAt, ctx.now, calendar: ctx.calendar)), "due": $0.1.due.map { .date($0) } ?? .null]) }
        return ContextPack(moduleID: .promises, summary: "\(open.count) open promises", data: .array(rows), evidenceIDs: open.map { $0.0.id.uuidString })
    }
}
