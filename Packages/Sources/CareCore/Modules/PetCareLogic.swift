import Foundation

public enum PetCareKind: String, Codable, CaseIterable, Sendable, Hashable {
    case vetVisit, vaccination, deworming, grooming, foodOrder, medicine, weight, bath, tickTreatment

    public var label: String {
        switch self {
        case .vetVisit: "Vet visit"
        case .vaccination: "Vaccination"
        case .deworming: "Deworming"
        case .grooming: "Grooming"
        case .foodOrder: "Food order"
        case .medicine: "Medicine"
        case .weight: "Weight"
        case .bath: "Bath"
        case .tickTreatment: "Tick treatment"
        }
    }

    public var symbol: String {
        switch self {
        case .vetVisit: "stethoscope"
        case .vaccination: "syringe"
        case .deworming: "pills"
        case .grooming: "scissors"
        case .foodOrder: "bag"
        case .medicine: "cross.vial"
        case .weight: "scalemass"
        case .bath: "drop"
        case .tickTreatment: "ant"
        }
    }

    /// Typical interval, used to prefill the next due date.
    public var defaultIntervalDays: Int? {
        switch self {
        case .vetVisit: 365
        case .vaccination: 365
        case .deworming: 90
        case .grooming: 45
        case .foodOrder: 30
        case .medicine: nil
        case .weight: 30
        case .bath: 14
        case .tickTreatment: 30
        }
    }
}

public struct PetCareSettings: Codable, Hashable, Sendable {
    public var species: String
    public var breed: String
    public var vetName: String?
    public var vetPhone: String?
    public var foodBrand: String?
    public var foodDaysSupply: Int
    public init(species: String = "Dog", breed: String = "", vetName: String? = nil, vetPhone: String? = nil, foodBrand: String? = nil, foodDaysSupply: Int = 30) {
        self.species = species
        self.breed = breed
        self.vetName = vetName
        self.vetPhone = vetPhone
        self.foodBrand = foodBrand
        self.foodDaysSupply = foodDaysSupply
    }
}

public struct PetCarePayload: Codable, Hashable, Sendable {
    public var kind: PetCareKind
    public var note: String?
    public var nextDue: Date?
    public var value: Double?          // weight in kg, cost, etc.
    public var medicineName: String?
    public init(kind: PetCareKind, note: String? = nil, nextDue: Date? = nil, value: Double? = nil, medicineName: String? = nil) {
        self.kind = kind
        self.note = note
        self.nextDue = nextDue
        self.value = value
        self.medicineName = medicineName
    }
}

public enum PetCareLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.petCare)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .countdown, .list, .trend, .action, .note]
    public static let reminderRules = [
        ReminderRule(id: "pet.due", kind: .petCare, description: "Vet check, vaccine and deworming due dates; food running low"),
    ]

    public struct Due: Hashable, Sendable {
        public var kind: PetCareKind
        public var date: Date
        public var days: Int
        public var note: String?
    }

    public static func settings(_ ctx: ModuleContext) -> PetCareSettings {
        ctx.person.settings(PetCareSettings.self, for: .petCare) ?? PetCareSettings()
    }

    /// The latest entry of each kind, and when it says the next one is due.
    public static func dues(_ ctx: ModuleContext) -> [Due] {
        var latest: [PetCareKind: (EntryRecord, PetCarePayload)] = [:]
        for e in ctx.entries {
            guard let p = e.decode(PetCarePayload.self) else { continue }
            if let cur = latest[p.kind], cur.0.occurredAt > e.occurredAt { continue }
            latest[p.kind] = (e, p)
        }
        var out: [Due] = []
        for (kind, pair) in latest {
            var due = pair.1.nextDue
            if due == nil, kind == .foodOrder { due = CareDates.adding(days: settings(ctx).foodDaysSupply, to: pair.0.occurredAt, calendar: ctx.calendar) }
            if due == nil, let interval = kind.defaultIntervalDays, kind != .weight, kind != .medicine { due = CareDates.adding(days: interval, to: pair.0.occurredAt, calendar: ctx.calendar) }
            guard let d = due else { continue }
            out.append(Due(kind: kind, date: d, days: CareDates.daysBetween(ctx.now, d, calendar: ctx.calendar), note: pair.1.note))
        }
        return out.sorted { $0.days < $1.days }
    }

    public static func latestWeight(_ ctx: ModuleContext) -> Double? {
        ctx.entries.compactMap { e -> Double? in
            guard let p = e.decode(PetCarePayload.self), p.kind == .weight else { return nil }
            return p.value
        }.first
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        guard let next = dues(ctx).first else { return ModuleTodayState(headline: "All good", detail: "Log a vet visit or food order", tone: .positive) }
        let headline = next.days <= 0 ? "Due now" : "\(next.days)d"
        return ModuleTodayState(headline: headline, detail: "\(next.kind.label)\(next.kind == .foodOrder ? " · food runs out" : "")",
                                tone: next.days <= 3 ? .attention : (next.days <= 14 ? .upcoming : .neutral), needsAttention: next.days <= 3)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        return dues(ctx).compactMap { d in
            if d.kind == .foodOrder {
                guard d.days <= 5 else { return nil }
                return Signal(id: ModuleHelpers.signalID(.petCare, .petFoodLow, p.id), personID: p.id, moduleID: .petCare, kind: .petFoodLow,
                              title: "\(p.shortName). Food runs out \(d.days <= 0 ? "today" : "in \(ModuleHelpers.plural(d.days, "day"))")",
                              body: settings(ctx).foodBrand.map { "Reorder \($0)." } ?? "Reorder the usual.",
                              at: d.date, priority: d.days <= 1 ? 0.6 : 0.45, tone: d.days <= 1 ? .attention : .upcoming,
                              hero: .numeral(value: "\(max(0, d.days))", unit: d.days == 1 ? "day of food" : "days of food"),
                              actions: [SignalAction(title: "Order food", kind: .log, link: .newEntry(personID: p.id, module: .petCare, title: "foodOrder"), isPrimary: true)])
            }
            guard d.days <= 14 else { return nil }
            return Signal(id: ModuleHelpers.signalID(.petCare, .petCareDue, p.id, suffix: d.kind.rawValue), personID: p.id, moduleID: .petCare, kind: .petCareDue,
                          title: "\(p.shortName). \(d.kind.label) \(d.days <= 0 ? "due" : "in \(ModuleHelpers.plural(d.days, "day"))")",
                          body: d.note ?? (settings(ctx).vetName.map { "Book with \($0)." } ?? "Book it this week."),
                          at: d.date, priority: d.days <= 0 ? 0.6 : 0.4, tone: d.days <= 3 ? .attention : .upcoming, hero: .countdown(d.date),
                          actions: [SignalAction(title: "Log it", kind: .log, link: .newEntry(personID: p.id, module: .petCare, title: d.kind.rawValue), isPrimary: true),
                                    SignalAction(title: "Open", link: .module(personID: p.id, module: .petCare))])
        }
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let dues = dues(ctx)
        let weights = ctx.entries.compactMap { e -> JSONValue? in
            guard let p = e.decode(PetCarePayload.self), p.kind == .weight, let v = p.value else { return nil }
            return .object(["d": .string(CareDates.shortDay(e.occurredAt)), "kg": .number(v)])
        }
        guard !dues.isEmpty || !weights.isEmpty else { return nil }
        let s = settings(ctx)
        return ContextPack(moduleID: .petCare, summary: "\(dues.count) things due, \(weights.count) weights",
                           data: .object(["breed": .string(s.breed), "due": .array(dues.map { .object(["kind": .string($0.kind.rawValue), "days": .int($0.days)]) }), "weights": .array(Array(weights.prefix(8)))]))
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let p = ctx.person
        return dues(ctx).compactMap { d in
            guard d.days == 3 || d.days == 0 else { return nil }
            return ReminderCandidate(id: "pet.\(d.kind.rawValue).\(p.id.uuidString.prefix(8)).\(d.days)", personID: p.id, moduleID: .petCare, kind: .petCare,
                                     earliest: CareDates.at(hour: 10, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 18, on: ctx.now, calendar: ctx.calendar),
                                     priority: 0.45, message: "\(p.shortName)'s \(d.kind.label.lowercased()) \(d.days == 0 ? "is today" : "in 3 days").", reason: "Pet care due date",
                                     actions: [ReminderAction(id: "log", title: "Log it")], link: .module(personID: p.id, module: .petCare))
        }
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        dues(ctx).filter { ctx.calendar.isDate($0.date, inSameDayAs: day) }.map { d in
            TimelineItem(id: "pet.\(d.kind.rawValue).\(ctx.person.id.uuidString.prefix(8))", personID: ctx.person.id, moduleID: .petCare,
                         title: "\(ctx.person.shortName): \(d.kind.label.lowercased())", subtitle: d.note ?? "Pet care", start: CareDates.at(hour: 10, on: day, calendar: ctx.calendar),
                         isAllDay: true, tone: .upcoming, link: .module(personID: ctx.person.id, module: .petCare))
        }
    }
}
