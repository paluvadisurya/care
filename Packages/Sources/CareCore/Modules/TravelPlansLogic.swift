import Foundation

public struct PackingItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var done: Bool
    public init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}

public struct TripPayload: Codable, Hashable, Sendable {
    public var destination: String
    public var from: Date
    public var to: Date
    public var travelers: [String]
    public var packing: [PackingItem]
    public var notes: String?

    public init(destination: String, from: Date, to: Date, travelers: [String] = [], packing: [PackingItem] = [], notes: String? = nil) {
        self.destination = destination
        self.from = from
        self.to = to
        self.travelers = travelers
        self.packing = packing
        self.notes = notes
    }

    public var packedCount: Int { packing.filter(\.done).count }
    public var packingProgress: Double { packing.isEmpty ? 0 : Double(packedCount) / Double(packing.count) }
}

public enum TravelPlansLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.travelPlans)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .countdown, .list, .action, .insight, .note]
    public static let reminderRules = [
        ReminderRule(id: "travel.pack", kind: .travel, description: "Seven days out: packing list. Day before. Arrival check. Welcome home."),
    ]

    public static func trips(_ ctx: ModuleContext) -> [(entry: EntryRecord, trip: TripPayload)] {
        ctx.entries.compactMap { e -> (entry: EntryRecord, trip: TripPayload)? in
            guard let t = e.decode(TripPayload.self) else { return nil }
            return (e, t)
        }
    }

    public static func nextTrip(_ ctx: ModuleContext) -> (entry: EntryRecord, trip: TripPayload)? {
        trips(ctx).filter { $0.trip.to >= ctx.calendar.startOfDay(for: ctx.now) }.min { $0.trip.from < $1.trip.from }
    }

    public static func isAway(_ ctx: ModuleContext) -> TripPayload? {
        trips(ctx).map(\.trip).first { $0.from <= ctx.now && ctx.now <= CareDates.adding(days: 1, to: $0.to, calendar: ctx.calendar) }
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        if let away = isAway(ctx) {
            return ModuleTodayState(headline: "In \(away.destination)", detail: "Back \(CareDates.relativeDays(from: ctx.now, to: away.to))", tone: .neutral)
        }
        guard let next = nextTrip(ctx) else { return ModuleTodayState(headline: "No trips", detail: "Plan one") }
        let d = CareDates.daysBetween(ctx.now, next.trip.from, calendar: ctx.calendar)
        return ModuleTodayState(headline: "\(next.trip.destination) · \(d)d", detail: next.trip.packing.isEmpty ? "No packing list yet" : "Packed \(next.trip.packedCount) of \(next.trip.packing.count)",
                                progress: next.trip.packing.isEmpty ? nil : next.trip.packingProgress, tone: d <= 7 ? .upcoming : .neutral)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        if let away = isAway(ctx) {
            return [Signal(id: ModuleHelpers.signalID(.travelPlans, .travelAway, p.id), personID: p.id, moduleID: .travelPlans, kind: .travelAway,
                           title: "\(p.shortName) is in \(away.destination)", body: "Back \(CareDates.relativeDays(from: ctx.now, to: away.to)). Other nudges paused.",
                           at: away.to, priority: 0.25, tone: .neutral,
                           actions: [SignalAction(title: "Message", kind: .message, link: .person(p.id), isPrimary: true)])]
        }
        guard let next = nextTrip(ctx) else { return [] }
        let d = CareDates.daysBetween(ctx.now, next.trip.from, calendar: ctx.calendar)
        guard d <= 7 else { return [] }
        let packing = next.trip.packing.isEmpty ? "No packing list yet." : "Packed \(next.trip.packedCount) of \(next.trip.packing.count)."
        return [Signal(id: ModuleHelpers.signalID(.travelPlans, .travelSoon, p.id), personID: p.id, moduleID: .travelPlans, kind: .travelSoon,
                       title: "\(p.shortName). \(next.trip.destination) \(d == 0 ? "today" : d == 1 ? "tomorrow" : "in \(d) days")", body: packing,
                       at: next.trip.from, priority: 0.45 + Double(7 - d) / 7 * 0.2, tone: .upcoming, hero: .countdown(next.trip.from),
                       actions: [SignalAction(title: "Packing list", link: .module(personID: p.id, module: .travelPlans), isPrimary: true)])]
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let rows = trips(ctx).filter { $0.trip.to >= ctx.now }.map { t -> JSONValue in
            .object(["id": .string(t.entry.id.uuidString), "dest": .string(t.trip.destination), "from": .date(t.trip.from), "to": .date(t.trip.to),
                     "packing": .string("\(t.trip.packedCount)/\(t.trip.packing.count)"), "who": .array(t.trip.travelers.map { .string($0) })])
        }
        guard !rows.isEmpty else { return nil }
        return ContextPack(moduleID: .travelPlans, summary: "\(rows.count) upcoming trips", data: .array(rows))
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let p = ctx.person
        guard let next = nextTrip(ctx) else { return [] }
        let d = CareDates.daysBetween(ctx.now, next.trip.from, calendar: ctx.calendar)
        var out: [ReminderCandidate] = []
        if d == 7 || d == 1 {
            out.append(ReminderCandidate(
                id: "travel.\(next.entry.id.uuidString.prefix(8)).\(d)", personID: p.id, moduleID: .travelPlans, kind: .travel,
                earliest: CareDates.at(hour: 18, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 21, on: ctx.now, calendar: ctx.calendar),
                priority: 0.5, message: d == 7 ? "\(next.trip.destination) in a week. Start the packing list?" : "\(next.trip.destination) tomorrow. Packed \(next.trip.packedCount) of \(next.trip.packing.count).",
                reason: "Travel lead time", actions: [ReminderAction(id: "packing", title: "Packing")], link: .module(personID: p.id, module: .travelPlans)))
        }
        if d == 0 {
            out.append(ReminderCandidate(
                id: "travel.arrive.\(next.entry.id.uuidString.prefix(8))", personID: p.id, moduleID: .travelPlans, kind: .travel,
                earliest: CareDates.at(hour: 19, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 21, on: ctx.now, calendar: ctx.calendar),
                priority: 0.4, message: "\(p.shortName) should be in \(next.trip.destination) by now. A quick message?", reason: "Safe arrival check",
                actions: [ReminderAction(id: "message", title: "Message")], link: .person(p.id)))
        }
        return out
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        trips(ctx).compactMap { t in
            let start = ctx.calendar.startOfDay(for: t.trip.from)
            let end = ctx.calendar.startOfDay(for: t.trip.to)
            let d = ctx.calendar.startOfDay(for: day)
            guard d >= start, d <= end else { return nil }
            let label = d == start ? "Leaves for \(t.trip.destination)" : d == end ? "Back from \(t.trip.destination)" : "In \(t.trip.destination)"
            return TimelineItem(id: "trip.\(t.entry.id.uuidString.prefix(8)).\(CareDates.isoDay(day))", personID: ctx.person.id, moduleID: .travelPlans,
                                title: label, subtitle: ctx.person.shortName, start: d, isAllDay: true, tone: .neutral,
                                link: .module(personID: ctx.person.id, module: .travelPlans))
        }
    }
}
