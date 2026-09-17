import Foundation

public enum HealthState: String, Codable, CaseIterable, Sendable, Hashable {
    case allGood, neutral, notGood

    public var label: String {
        switch self {
        case .allGood: "All good"
        case .neutral: "Neutral"
        case .notGood: "Not good"
        }
    }
}

public enum ReadingKind: String, Codable, CaseIterable, Sendable, Hashable {
    case bloodPressure, bloodSugar, weight, temperature

    public var label: String {
        switch self {
        case .bloodPressure: "Blood pressure"
        case .bloodSugar: "Blood sugar"
        case .weight: "Weight"
        case .temperature: "Temperature"
        }
    }
}

public struct HealthReading: Codable, Hashable, Sendable {
    public var kind: ReadingKind
    public var systolic: Int?
    public var diastolic: Int?
    public var value: Double?
    public var unit: String?
    public var context: String?      // "fasting", "post meal"

    public init(kind: ReadingKind, systolic: Int? = nil, diastolic: Int? = nil, value: Double? = nil, unit: String? = nil, context: String? = nil) {
        self.kind = kind
        self.systolic = systolic
        self.diastolic = diastolic
        self.value = value
        self.unit = unit
        self.context = context
    }

    public var label: String {
        switch kind {
        case .bloodPressure: "\(systolic ?? 0)/\(diastolic ?? 0)"
        case .bloodSugar: "\(Int(value ?? 0)) \(unit ?? "mg/dL")\(context.map { " \($0)" } ?? "")"
        case .weight: String(format: "%.1f %@", value ?? 0, unit ?? "kg")
        case .temperature: String(format: "%.1f %@", value ?? 0, unit ?? "°C")
        }
    }

    /// Above the commonly quoted range. This is a nudge to talk to a doctor, never a diagnosis.
    public var isAboveUsualRange: Bool {
        switch kind {
        case .bloodPressure: (systolic ?? 0) >= 140 || (diastolic ?? 0) >= 90
        case .bloodSugar:
            if context?.lowercased().contains("fast") == true { return (value ?? 0) >= 126 }
            return (value ?? 0) >= 200
        case .temperature: (value ?? 0) >= 38
        case .weight: false
        }
    }
}

public struct HealthPayload: Codable, Hashable, Sendable {
    public var state: HealthState
    public var symptoms: [String]
    public var note: String?
    public var reading: HealthReading?

    public init(state: HealthState, symptoms: [String] = [], note: String? = nil, reading: HealthReading? = nil) {
        self.state = state
        self.symptoms = symptoms
        self.note = note
        self.reading = reading
    }

    public static let symptomChips = ["headache", "back pain", "tired", "cold", "fever", "stomach", "dizzy", "knee", "sleep", "stress"]
}

public enum HealthLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.health)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .trend, .list, .insight, .note, .action]
    public static let reminderRules = [
        ReminderRule(id: "health.symptom", kind: .signal, description: "A symptom logged three days running"),
        ReminderRule(id: "health.reading", kind: .signal, description: "A reading above the usual range"),
    ]

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        guard let last = ctx.entries.first, let p = last.decode(HealthPayload.self) else {
            return ModuleTodayState(headline: "All good?", detail: "Nothing logged")
        }
        let streak = symptomStreak(ctx)
        var headline = p.state.label
        if let r = p.reading { headline = r.label }
        var detail = CareDates.relativeShort(from: ctx.now, to: last.occurredAt)
        if let s = streak, s.days >= 2 { detail = "\(s.symptom), day \(s.days)" }
        let tone: Tone = p.reading?.isAboveUsualRange == true || p.state == .notGood ? .attention : (p.state == .allGood ? .positive : .neutral)
        return ModuleTodayState(headline: headline, detail: detail, tone: tone, needsAttention: tone == .attention)
    }

    public static func symptomStreak(_ ctx: ModuleContext) -> (symptom: String, days: Int)? {
        guard let latest = ctx.entries.first?.decode(HealthPayload.self), let symptom = latest.symptoms.first else { return nil }
        let days = ModuleHelpers.streak(ctx.entries, now: ctx.now, calendar: ctx.calendar) {
            $0.decode(HealthPayload.self)?.symptoms.contains(symptom) == true
        }
        return days > 0 ? (symptom, days) : nil
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        var out: [Signal] = []
        let p = ctx.person
        if let s = symptomStreak(ctx), s.days >= 3 {
            out.append(Signal(
                id: ModuleHelpers.signalID(.health, .symptomStreak, p.id), personID: p.id, moduleID: .health, kind: .symptomStreak,
                title: "\(p.shortName). \(s.symptom.capitalized), day \(s.days)", body: "Three days running. Worth a call, maybe a doctor.",
                priority: 0.6, tone: .attention, hero: .word("Day \(s.days)"),
                actions: [SignalAction(title: "Call \(p.shortName)", kind: .call, link: .person(p.id), isPrimary: true),
                          SignalAction(title: "Log", kind: .log, link: .newEntry(personID: p.id, module: .health, title: nil))]))
        }
        if let latest = ctx.entries.first, let r = latest.decode(HealthPayload.self)?.reading, r.isAboveUsualRange,
           CareDates.daysBetween(latest.occurredAt, ctx.now, calendar: ctx.calendar) <= 2 {
            out.append(Signal(
                id: ModuleHelpers.signalID(.health, .readingHigh, p.id), personID: p.id, moduleID: .health, kind: .readingHigh,
                title: "\(p.shortName). \(r.kind.label) \(r.label)", body: "Above the usual range. Recheck later today and mention it to the doctor.",
                at: latest.occurredAt, priority: 0.55, tone: .attention, hero: .word(r.label),
                actions: [SignalAction(title: "Log a recheck", kind: .log, link: .newEntry(personID: p.id, module: .health, title: r.kind.label), isPrimary: true)]))
        }
        return out
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let entries = ctx.entries(in: window)
        guard !entries.isEmpty else { return nil }
        let readings = entries.compactMap { e -> JSONValue? in
            guard let r = e.decode(HealthPayload.self)?.reading else { return nil }
            return .object(["d": .string(CareDates.shortDay(e.occurredAt)), "kind": .string(r.kind.rawValue), "v": .string(r.label),
                            "high": .bool(r.isAboveUsualRange)])
        }
        var states: [String: Int] = [:]
        for e in entries { if let s = e.decode(HealthPayload.self)?.state { states[s.rawValue, default: 0] += 1 } }
        var streaks: [JSONValue] = []
        if let s = symptomStreak(ctx) { streaks.append(.object(["symptom": .string(s.symptom), "days": .int(s.days)])) }
        let data: JSONValue = .object([
            "private_to_user": .bool(true), "states": .object(states.mapValues { .int($0) }),
            "readings": .array(Array(readings.prefix(12))), "streaks": .array(streaks), "entries": .int(entries.count),
        ])
        return ContextPack(moduleID: .health, summary: "\(entries.count) health notes, \(readings.count) readings",
                           data: data, privateToUser: true, evidenceIDs: entries.map { $0.id.uuidString })
    }
}
