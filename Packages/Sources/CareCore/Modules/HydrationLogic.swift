import Foundation

public struct HydrationPayload: Codable, Hashable, Sendable {
    public var milliliters: Int
    public init(milliliters: Int) { self.milliliters = milliliters }
}

public struct HydrationSettings: Codable, Hashable, Sendable {
    public var targetML: Int
    public var cupML: Int
    public init(targetML: Int = 2500, cupML: Int = 250) {
        self.targetML = targetML
        self.cupML = cupML
    }
    public static let `default` = HydrationSettings()
}

public enum HydrationLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.hydration)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .trend, .compare, .insight, .note]
    public static let reminderRules = [
        ReminderRule(id: "hydration.pace", kind: .hydration, description: "Behind pace in the afternoon, never at night"),
    ]

    public static func settings(_ ctx: ModuleContext) -> HydrationSettings {
        ctx.person.settings(HydrationSettings.self, for: .hydration) ?? .default
    }

    public static func total(on day: Date, _ ctx: ModuleContext) -> Int {
        ctx.entries.filter { ctx.calendar.isDate($0.occurredAt, inSameDayAs: day) }
            .compactMap { $0.decode(HydrationPayload.self)?.milliliters }.reduce(0, +)
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        let s = settings(ctx)
        let t = total(on: ctx.now, ctx)
        let progress = min(1, Double(t) / Double(max(1, s.targetML)))
        return ModuleTodayState(headline: ModuleHelpers.litres(t), detail: "of \(ModuleHelpers.litres(s.targetML))",
                                progress: progress, tone: progress >= 1 ? .positive : .neutral)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let s = settings(ctx)
        let t = total(on: ctx.now, ctx)
        let progress = Double(t) / Double(max(1, s.targetML))
        let hour = CareDates.hour(of: ctx.now, calendar: ctx.calendar)
        let p = ctx.person
        guard hour >= 13, hour < 21 else { return [] }
        let expected = Double(hour - 8) / 13.0
        guard progress < expected * 0.6 else { return [] }
        let pct = Int((progress * 100).rounded())
        return [Signal(
            id: ModuleHelpers.signalID(.hydration, .hydrationBehind, p.id), personID: p.id, moduleID: .hydration, kind: .hydrationBehind,
            title: "\(p.shortName). Water", body: "\(ModuleHelpers.litres(t)) so far, \(pct)% of today.",
            at: CareDates.at(hour: hour, on: ctx.now, calendar: ctx.calendar), priority: 0.3, tone: .upcoming,
            hero: .numeral(value: ModuleHelpers.litres(t), unit: "of \(ModuleHelpers.litres(s.targetML))"),
            actions: [SignalAction(title: "+\(s.cupML) ml", kind: .log, link: .newEntry(personID: p.id, module: .hydration, title: "\(s.cupML)"), isPrimary: true)])]
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let s = settings(ctx)
        let days = max(1, min(30, CareDates.daysBetween(window.start, window.end, calendar: ctx.calendar)))
        var totals: [JSONValue] = []
        var hits = 0
        var sum = 0
        for offset in (0..<days).reversed() {
            let day = CareDates.adding(days: -offset, to: ctx.now, calendar: ctx.calendar)
            let t = total(on: day, ctx)
            totals.append(.int(t))
            sum += t
            if t >= s.targetML { hits += 1 }
        }
        guard sum > 0 else { return nil }
        let data: JSONValue = .object([
            "target_ml": .int(s.targetML), "days": .int(days), "hit_days": .int(hits),
            "avg_ml": .int(sum / days), "daily_ml": .array(totals),
        ])
        return ContextPack(moduleID: .hydration, summary: "hit target \(hits) of \(days) days", data: data)
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let s = settings(ctx)
        let p = ctx.person
        let t = total(on: ctx.now, ctx)
        guard t < s.targetML else { return [] }
        return [ReminderCandidate(
            id: "hydration.\(p.id.uuidString.prefix(8)).\(CareDates.isoDay(ctx.now))", personID: p.id, moduleID: .hydration, kind: .hydration,
            earliest: CareDates.at(hour: 13, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 20, on: ctx.now, calendar: ctx.calendar),
            priority: 0.25, message: "Water: \(ModuleHelpers.litres(t)) of \(ModuleHelpers.litres(s.targetML))", reason: "Behind the usual pace",
            actions: [ReminderAction(id: "water.250", title: "+250 ml"), ReminderAction(id: "water.500", title: "+500 ml")],
            link: .module(personID: p.id, module: .hydration))]
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        guard ctx.calendar.isDate(day, inSameDayAs: ctx.now) else { return [] }
        let s = settings(ctx)
        let t = total(on: day, ctx)
        return [TimelineItem(id: "hydration.\(ctx.person.id.uuidString.prefix(8))", personID: ctx.person.id, moduleID: .hydration,
                             title: "Water check", subtitle: "\(ModuleHelpers.litres(t)) of \(ModuleHelpers.litres(s.targetML)). Tap to add",
                             start: CareDates.at(hour: 13, on: day, calendar: ctx.calendar), tone: t >= s.targetML ? .positive : .neutral,
                             link: .module(personID: ctx.person.id, module: .hydration), isDone: t >= s.targetML)]
    }
}
