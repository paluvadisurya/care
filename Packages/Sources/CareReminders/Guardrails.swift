import Foundation
import CareCore

/// Preferences that shape what gets sent. Stored by the app, passed in here.
public struct ReminderPreferences: Codable, Hashable, Sendable {
    public var dailyCap: Int
    public var quietHours: [String]
    public var morningBriefHour: Int
    public var eveningWrapHour: Int
    public var eveningWrapEnabled: Bool
    public var mutedKinds: Set<ReminderKind>
    /// Kinds ignored three times in a row for a person get lowered. Key: "kind.personID".
    public var loweredKeys: Set<String>

    public init(dailyCap: Int = 5, quietHours: [String] = ["22:00", "07:00"], morningBriefHour: Int = 8, eveningWrapHour: Int = 21,
                eveningWrapEnabled: Bool = true, mutedKinds: Set<ReminderKind> = [], loweredKeys: Set<String> = []) {
        self.dailyCap = dailyCap
        self.quietHours = quietHours
        self.morningBriefHour = morningBriefHour
        self.eveningWrapHour = eveningWrapHour
        self.eveningWrapEnabled = eveningWrapEnabled
        self.mutedKinds = mutedKinds
        self.loweredKeys = loweredKeys
    }

    public static let `default` = ReminderPreferences()
}

/// A reminder ready to schedule. Time chosen, message final.
public struct PlannedReminder: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var personID: UUID
    public var personName: String
    public var moduleID: ModuleID
    public var kind: ReminderKind
    public var fireAt: Date
    public var message: String
    public var reason: String
    public var actions: [ReminderAction]
    public var interruption: InterruptionLevel
    public var link: DeepLink

    public init(candidate: ReminderCandidate, personName: String, fireAt: Date, message: String? = nil) {
        id = candidate.id
        personID = candidate.personID
        self.personName = personName
        moduleID = candidate.moduleID
        kind = candidate.kind
        self.fireAt = fireAt
        self.message = message ?? candidate.message
        reason = candidate.reason
        actions = candidate.actions
        interruption = candidate.interruption
        link = candidate.link
    }
}

/// Daily cap, quiet hours, dedupe, priority decay, no sensitive content in previews. The app has the final say.
public enum Guardrails {
    public static func apply(_ candidates: [ReminderCandidate], people: [PersonRecord], prefs: ReminderPreferences,
                             now: Date, calendar: Calendar = .care, awayPeople: Set<UUID> = []) -> [PlannedReminder] {
        var seen: Set<String> = []
        var planned: [PlannedReminder] = []
        let sorted = candidates.sorted { a, b in
            let pa = adjustedPriority(a, prefs: prefs)
            let pb = adjustedPriority(b, prefs: prefs)
            if pa != pb { return pa > pb }
            return a.earliest < b.earliest
        }
        for c in sorted {
            guard !prefs.mutedKinds.contains(c.kind) else { continue }
            // Travel sets an away state that pauses hydration and pulse checks for that person.
            if awayPeople.contains(c.personID), c.kind == .hydration || c.kind == .pulseCheck { continue }
            let dedupeKey = "\(c.kind.rawValue).\(c.personID.uuidString).\(CareDates.isoDay(c.earliest))"
            guard !seen.contains(dedupeKey) else { continue }
            guard let fireAt = pickTime(c, prefs: prefs, now: now, calendar: calendar) else { continue }
            guard let person = people.first(where: { $0.id == c.personID }) else { continue }
            // Medication is exempt from the cap. Everything else counts.
            let countsTowardCap = c.kind != .medication
            let todayCount = planned.filter { calendar.isDate($0.fireAt, inSameDayAs: fireAt) && $0.kind != .medication }.count
            if countsTowardCap, todayCount >= prefs.dailyCap { continue }
            seen.insert(dedupeKey)
            planned.append(PlannedReminder(candidate: c, personName: person.shortName, fireAt: fireAt, message: safeMessage(c)))
        }
        return planned.sorted { $0.fireAt < $1.fireAt }
    }

    static func adjustedPriority(_ c: ReminderCandidate, prefs: ReminderPreferences) -> Double {
        prefs.loweredKeys.contains("\(c.kind.rawValue).\(c.personID.uuidString)") ? c.priority * 0.5 : c.priority
    }

    /// Earliest allowed moment outside quiet hours and in the future.
    static func pickTime(_ c: ReminderCandidate, prefs: ReminderPreferences, now: Date, calendar: Calendar) -> Date? {
        var t = max(c.earliest, now.addingTimeInterval(60))
        guard t <= c.latest || c.kind == .medication else { return nil }
        if c.kind == .medication { return t }
        var guardCount = 0
        while CareDates.isQuiet(t, quietHours: prefs.quietHours, calendar: calendar), guardCount < 48 {
            t = CareDates.adding(hours: 1, to: t, calendar: calendar)
            guardCount += 1
        }
        return t <= c.latest ? t : nil
    }

    /// Health details never appear in a lock screen preview. The person's name and the action do.
    static func safeMessage(_ c: ReminderCandidate) -> String {
        switch c.kind {
        case .signal where c.moduleID == .health: "Something about their health is worth a look."
        default: c.message
        }
    }

    /// Standing reminders that do not come from a module.
    public static func standing(prefs: ReminderPreferences, now: Date, calendar: Calendar = .care, peopleCount: Int, meID: UUID) -> [PlannedReminder] {
        var out: [PlannedReminder] = []
        let brief = ReminderCandidate(id: "brief.\(CareDates.isoDay(now))", personID: meID, moduleID: .mood, kind: .morningBrief,
                                      earliest: CareDates.at(hour: prefs.morningBriefHour, on: now, calendar: calendar), latest: CareDates.at(hour: prefs.morningBriefHour + 1, on: now, calendar: calendar),
                                      priority: 1, message: "Your morning brief is ready.", reason: "Morning brief", actions: [ReminderAction(id: "open", title: "Open")], link: .today)
        if brief.earliest > now { out.append(PlannedReminder(candidate: brief, personName: "Care", fireAt: brief.earliest)) }
        if prefs.eveningWrapEnabled {
            let wrap = ReminderCandidate(id: "wrap.\(CareDates.isoDay(now))", personID: meID, moduleID: .mood, kind: .eveningWrap,
                                         earliest: CareDates.at(hour: prefs.eveningWrapHour, on: now, calendar: calendar), latest: CareDates.at(hour: prefs.eveningWrapHour + 1, on: now, calendar: calendar),
                                         priority: 1, message: "One minute. Three questions about the people you saw today.", reason: "Evening wrap",
                                         actions: [ReminderAction(id: "open", title: "Open"), ReminderAction(id: "skip", title: "Skip")], link: .today)
            if wrap.earliest > now { out.append(PlannedReminder(candidate: wrap, personName: "Care", fireAt: wrap.earliest)) }
        }
        return out
    }
}
