import Foundation

public struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    public var hour: Int
    public var minute: Int
    public init(hour: Int, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }
    public static func < (a: TimeOfDay, b: TimeOfDay) -> Bool { (a.hour, a.minute) < (b.hour, b.minute) }
    public var label: String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", h12, minute, hour < 12 ? "am" : "pm")
    }
    public func date(on day: Date, calendar: Calendar) -> Date {
        CareDates.at(hour: hour, minute: minute, on: day, calendar: calendar)
    }
}

public struct Medicine: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var dose: String
    public var times: [TimeOfDay]
    public var withFood: Bool
    public var purpose: String?
    public var refillDate: Date?
    public var givenBy: String?

    public init(id: UUID = UUID(), name: String, dose: String, times: [TimeOfDay], withFood: Bool = false,
                purpose: String? = nil, refillDate: Date? = nil, givenBy: String? = nil) {
        self.id = id
        self.name = name
        self.dose = dose
        self.times = times
        self.withFood = withFood
        self.purpose = purpose
        self.refillDate = refillDate
        self.givenBy = givenBy
    }
}

public struct MedicationSettings: Codable, Hashable, Sendable {
    public var medicines: [Medicine]
    public init(medicines: [Medicine] = []) { self.medicines = medicines }
}

public enum DoseStatus: String, Codable, Sendable, Hashable {
    case taken, skipped
}

public struct DosePayload: Codable, Hashable, Sendable {
    public var medicineID: UUID
    public var scheduledAt: Date
    public var status: DoseStatus
    public init(medicineID: UUID, scheduledAt: Date, status: DoseStatus) {
        self.medicineID = medicineID
        self.scheduledAt = scheduledAt
        self.status = status
    }
}

/// One scheduled dose on one day, with what happened to it.
public struct DoseSlot: Hashable, Sendable, Identifiable {
    public enum State: String, Sendable { case upcoming, due, missed, taken, skipped }
    public var id: String
    public var medicine: Medicine
    public var scheduledAt: Date
    public var state: State
}

public enum MedicationLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.medication)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .compare, .list, .insight, .note, .action]
    public static let reminderRules = [
        ReminderRule(id: "medication.dose", kind: .medication, description: "Dose time, time-sensitive"),
        ReminderRule(id: "medication.refill", kind: .refill, description: "Refill five days ahead"),
    ]

    public static func settings(_ ctx: ModuleContext) -> MedicationSettings {
        ctx.person.settings(MedicationSettings.self, for: .medication) ?? MedicationSettings()
    }

    public static func slots(on day: Date, _ ctx: ModuleContext, graceMinutes: Int = 90) -> [DoseSlot] {
        let doses = ctx.entries.filter { ctx.calendar.isDate($0.occurredAt, inSameDayAs: day) }.compactMap { $0.decode(DosePayload.self) }
        var out: [DoseSlot] = []
        for m in settings(ctx).medicines {
            for t in m.times {
                let at = t.date(on: day, calendar: ctx.calendar)
                let logged = doses.first { $0.medicineID == m.id && abs($0.scheduledAt.timeIntervalSince(at)) < 60 * 30 }
                let state: DoseSlot.State
                if let logged {
                    state = logged.status == .taken ? .taken : .skipped
                } else if ctx.now.timeIntervalSince(at) > Double(graceMinutes * 60) {
                    state = .missed
                } else if abs(ctx.now.timeIntervalSince(at)) <= Double(graceMinutes * 60) {
                    state = .due
                } else {
                    state = .upcoming
                }
                out.append(DoseSlot(id: "\(m.id.uuidString.prefix(8)).\(t.hour).\(t.minute).\(CareDates.isoDay(day))", medicine: m, scheduledAt: at, state: state))
            }
        }
        return out.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// Taken over scheduled for the past `days` full days.
    public static func adherence(days: Int, _ ctx: ModuleContext) -> Double? {
        var taken = 0
        var scheduled = 0
        for offset in 1...max(1, days) {
            let day = CareDates.adding(days: -offset, to: ctx.now, calendar: ctx.calendar)
            for s in slots(on: day, ctx) {
                scheduled += 1
                if s.state == .taken { taken += 1 }
            }
        }
        guard scheduled > 0 else { return nil }
        return Double(taken) / Double(scheduled)
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        let today = slots(on: ctx.now, ctx)
        guard !today.isEmpty else { return ModuleTodayState(headline: "No medicines", detail: "Add one") }
        let taken = today.filter { $0.state == .taken }.count
        let missed = today.filter { $0.state == .missed }
        let detail: String
        if let m = missed.first { detail = "Missed \(m.medicine.name) \(CareDates.timeLabel(m.scheduledAt, calendar: ctx.calendar))" }
        else if let next = today.first(where: { $0.state == .upcoming || $0.state == .due }) { detail = "Next \(CareDates.timeLabel(next.scheduledAt, calendar: ctx.calendar))" }
        else { detail = "All done today" }
        return ModuleTodayState(headline: "\(taken) of \(today.count)", detail: detail, progress: Double(taken) / Double(today.count),
                                tone: missed.isEmpty ? (taken == today.count ? .positive : .neutral) : .attention, needsAttention: !missed.isEmpty)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        var out: [Signal] = []
        let today = slots(on: ctx.now, ctx)
        let missed = today.filter { $0.state == .missed }
        if !missed.isEmpty {
            let first = missed[0]
            let carer = first.medicine.givenBy.map { " \($0) gives it." } ?? ""
            out.append(Signal(
                id: ModuleHelpers.signalID(.medication, .missedDose, p.id), personID: p.id, moduleID: .medication, kind: .missedDose,
                title: "\(p.shortName). Missed dose", body: "\(first.medicine.name) at \(CareDates.timeLabel(first.scheduledAt, calendar: ctx.calendar)), not marked.\(carer)",
                at: first.scheduledAt, priority: 0.8, tone: .attention,
                hero: .numeral(value: "\(missed.count)", unit: missed.count == 1 ? "dose" : "doses"),
                actions: [SignalAction(title: "Mark taken", kind: .markTaken, link: .module(personID: p.id, module: .medication), isPrimary: true),
                          SignalAction(title: "Call \(p.shortName)", kind: .call, link: .person(p.id))]))
        }
        if let due = today.first(where: { $0.state == .due }), missed.isEmpty {
            out.append(Signal(
                id: ModuleHelpers.signalID(.medication, .doseDue, p.id), personID: p.id, moduleID: .medication, kind: .doseDue,
                title: "\(p.shortName). \(due.medicine.name)", body: "\(due.medicine.dose) at \(CareDates.timeLabel(due.scheduledAt, calendar: ctx.calendar))\(due.medicine.withFood ? ", with food" : "").",
                at: due.scheduledAt, priority: 0.5, tone: .upcoming, hero: .word("Due now"),
                actions: [SignalAction(title: "Mark taken", kind: .markTaken, link: .module(personID: p.id, module: .medication), isPrimary: true)]))
        }
        for m in settings(ctx).medicines {
            if let r = m.refillDate {
                let d = CareDates.daysBetween(ctx.now, r, calendar: ctx.calendar)
                if d <= 5 {
                    out.append(Signal(
                        id: ModuleHelpers.signalID(.medication, .refillSoon, p.id, suffix: m.id.uuidString.prefix(6).description),
                        personID: p.id, moduleID: .medication, kind: .refillSoon,
                        title: "\(p.shortName). Refill \(m.name)", body: d <= 0 ? "Ran out. Order today." : "Runs out in \(ModuleHelpers.plural(d, "day")).",
                        at: r, priority: d <= 0 ? 0.6 : 0.4, tone: .upcoming, hero: .countdown(r),
                        actions: [SignalAction(title: "Order", link: .module(personID: p.id, module: .medication), isPrimary: true)]))
                }
            }
        }
        return out
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let s = settings(ctx)
        guard !s.medicines.isEmpty else { return nil }
        var missedByDay: [String: Int] = [:]
        var taken = 0, scheduled = 0
        for offset in 1...14 {
            let day = CareDates.adding(days: -offset, to: ctx.now, calendar: ctx.calendar)
            for slot in slots(on: day, ctx) {
                scheduled += 1
                if slot.state == .taken { taken += 1 } else { missedByDay[CareDates.weekdayName(day, calendar: ctx.calendar), default: 0] += 1 }
            }
        }
        let data: JSONValue = .object([
            "medicines": .array(s.medicines.map { .object(["name": .string($0.name), "dose": .string($0.dose), "times": .array($0.times.map { .string($0.label) }),
                                                            "refill": $0.refillDate.map { .date($0) } ?? .null]) }),
            "taken_14d": .int(taken), "scheduled_14d": .int(scheduled), "missed_by_weekday": .object(missedByDay.mapValues { .int($0) }),
            "today": .array(slots(on: ctx.now, ctx).map { .object(["name": .string($0.medicine.name), "at": .string(CareDates.timeLabel($0.scheduledAt, calendar: ctx.calendar)), "state": .string($0.state.rawValue)]) }),
        ])
        return ContextPack(moduleID: .medication, summary: "\(taken) of \(scheduled) doses taken in 14 days", data: data, privateToUser: true)
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let p = ctx.person
        var out: [ReminderCandidate] = []
        for slot in slots(on: ctx.now, ctx) where slot.state == .upcoming || slot.state == .due {
            let carer = slot.medicine.givenBy.map { " \($0) gives it." } ?? ""
            out.append(ReminderCandidate(
                id: "medication.dose.\(slot.id)", personID: p.id, moduleID: .medication, kind: .medication,
                earliest: slot.scheduledAt, latest: CareDates.adding(hours: 1, to: slot.scheduledAt, calendar: ctx.calendar),
                priority: 0.9, message: "\(p.shortName)'s \(slot.medicine.name), \(slot.medicine.dose).\(carer)", reason: "Dose time",
                actions: [ReminderAction(id: "taken", title: "Taken"), ReminderAction(id: "skip", title: "Skip")],
                interruption: .timeSensitive, link: .module(personID: p.id, module: .medication)))
        }
        for m in settings(ctx).medicines {
            if let r = m.refillDate, CareDates.daysBetween(ctx.now, r, calendar: ctx.calendar) == 5 {
                out.append(ReminderCandidate(
                    id: "medication.refill.\(m.id.uuidString.prefix(8))", personID: p.id, moduleID: .medication, kind: .refill,
                    earliest: CareDates.at(hour: 10, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 18, on: ctx.now, calendar: ctx.calendar),
                    priority: 0.5, message: "\(p.shortName)'s \(m.name) runs out in 5 days.", reason: "Refill lead time",
                    actions: [ReminderAction(id: "order", title: "Order")], link: .module(personID: p.id, module: .medication)))
            }
        }
        return out
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        slots(on: day, ctx).map { s in
            TimelineItem(id: "dose.\(s.id)", personID: ctx.person.id, moduleID: .medication, title: "\(s.medicine.name), \(s.medicine.dose)",
                         subtitle: "\(ctx.person.shortName) · \(s.state == .missed ? "Missed" : s.state == .taken ? "Taken" : "Medication")",
                         start: s.scheduledAt, tone: s.state == .missed ? .attention : (s.state == .taken ? .positive : .neutral),
                         link: .module(personID: ctx.person.id, module: .medication), isDone: s.state == .taken)
        }
    }
}
