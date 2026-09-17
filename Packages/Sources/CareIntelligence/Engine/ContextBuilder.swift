import Foundation
import CareCore

/// Builds the scope context the model (or the local engine) reads. Pure and testable.
public struct ContextBuilder: Sendable {
    public var registry: ModuleRegistry
    public var calendar: Calendar
    public var userName: String
    public var quietHours: [String]

    public init(registry: ModuleRegistry = .standard, calendar: Calendar = .care, userName: String, quietHours: [String] = ["22:00", "07:00"]) {
        self.registry = registry
        self.calendar = calendar
        self.userName = userName
        self.quietHours = quietHours
    }

    public func person(_ person: PersonRecord, entries: [EntryRecord], events: [EventRecord], now: Date, days: Int = 30,
                       previous: InsightRecord? = nil) -> ScopeContext {
        let window = CareDates.window(days: days, endingAt: now, calendar: calendar)
        let packs = registry.packs(person: person, entries: entries, events: events, window: window, now: now)
        var blocks: Set<InsightBlockKind> = [.headline, .note]
        for m in person.enabledModules { if let l = registry.logic(for: m) { blocks.formUnion(l.allowedBlocks) } }
        return ScopeContext(
            scope: .person, today: CareDates.isoDay(now), userName: userName, timeZone: calendar.timeZone.identifier,
            quietHours: quietHours, person: PersonBrief(person), people: [PersonBrief(person)],
            allowedModules: person.enabledModules.filter { registry.isImplemented($0) },
            allowedBlocks: InsightBlockKind.allCases.filter { blocks.contains($0) },
            windowFrom: CareDates.isoDay(window.start), windowTo: CareDates.isoDay(window.end), packs: packs,
            previousHeadline: previous?.insight.headline, previousFeedback: previous?.feedback)
    }

    /// Home scope: one pack per person carrying today's ranked signals plus each person's module summaries.
    public func home(people: [PersonRecord], entries: [EntryRecord], events: [EventRecord], signals: [Signal], now: Date,
                     previous: InsightRecord? = nil) -> ScopeContext {
        let window = CareDates.window(days: 7, endingAt: now, calendar: calendar)
        var packs: [ContextPack] = []
        let ranked = HomeRanker.rank(signals, now: now)
        let signalRows = ranked.prefix(8).map { s -> JSONValue in
            .object(["person": .string(people.first { $0.id == s.personID }?.shortName ?? "?"), "module": .string(s.moduleID.rawValue),
                     "kind": .string(s.kind.rawValue), "title": .string(s.title), "body": .string(s.body), "tone": .string(s.tone.rawValue)])
        }
        packs.append(ContextPack(moduleID: .events, summary: "\(ranked.count) signals today", data: .object(["signals": .array(signalRows)])))
        for person in people where person.relationship != .me {
            let states = person.enabledModules.compactMap { m -> JSONValue? in
                guard let logic = registry.logic(for: m) else { return nil }
                let ctx = registry.context(person: person, module: m, entries: entries, events: events, now: now)
                let s = logic.todayState(ctx)
                return .object(["module": .string(m.rawValue), "state": .string(s.headline), "detail": .string(s.detail)])
            }
            packs.append(ContextPack(moduleID: .mood, summary: "\(person.shortName) today", data: .object(["person": .string(person.shortName), "relationship": .string(person.relationship.rawValue), "modules": .array(states)])))
        }
        let modules = Set(people.flatMap(\.enabledModules)).filter { registry.isImplemented($0) }.sorted()
        return ScopeContext(
            scope: .home, today: CareDates.isoDay(now), userName: userName, timeZone: calendar.timeZone.identifier, quietHours: quietHours,
            person: nil, people: people.map(PersonBrief.init), allowedModules: modules,
            allowedBlocks: [.headline, .stat, .list, .action, .insight, .note],
            windowFrom: CareDates.isoDay(window.start), windowTo: CareDates.isoDay(window.end), packs: packs,
            previousHeadline: previous?.insight.headline, previousFeedback: previous?.feedback)
    }

    public func weekly(_ person: PersonRecord, entries: [EntryRecord], events: [EventRecord], now: Date, previous: InsightRecord? = nil) -> ScopeContext {
        var ctx = self.person(person, entries: entries, events: events, now: now, days: 90, previous: previous)
        ctx.scope = .weekly
        return ctx
    }

    /// Stable hash of everything that could change the answer.
    public func inputHash(_ ctx: ScopeContext) -> String {
        var copy = ctx
        copy.previousHeadline = nil
        copy.previousFeedback = nil
        return PayloadCoder.inputHash(copy)
    }
}
