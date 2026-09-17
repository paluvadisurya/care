import Foundation

/// Shared helpers for module logic.
public enum ModuleHelpers {
    /// Latest entry per calendar day, newest first, for the last `days` days.
    public static func latestPerDay(_ entries: [EntryRecord], days: Int, now: Date, calendar: Calendar) -> [Date: EntryRecord] {
        var out: [Date: EntryRecord] = [:]
        let cutoff = CareDates.adding(days: -days, to: calendar.startOfDay(for: now), calendar: calendar)
        for e in entries where e.occurredAt >= cutoff {
            let day = calendar.startOfDay(for: e.occurredAt)
            if let existing = out[day], existing.occurredAt > e.occurredAt { continue }
            out[day] = e
        }
        return out
    }

    /// Values for the last `days` days ending today, oldest first. Nil for days without an entry.
    public static func trail(_ entries: [EntryRecord], days: Int, now: Date, calendar: Calendar,
                             value: (EntryRecord) -> Int?) -> [Int?] {
        let byDay = latestPerDay(entries, days: days, now: now, calendar: calendar)
        return (0..<days).reversed().map { offset in
            let day = calendar.startOfDay(for: CareDates.adding(days: -offset, to: now, calendar: calendar))
            return byDay[day].flatMap(value)
        }
    }

    /// Number of consecutive days ending today (or yesterday) where `predicate` holds for that day's latest entry.
    public static func streak(_ entries: [EntryRecord], now: Date, calendar: Calendar, maxDays: Int = 30,
                              predicate: (EntryRecord) -> Bool) -> Int {
        let byDay = latestPerDay(entries, days: maxDays, now: now, calendar: calendar)
        var count = 0
        var offset = 0
        // Allow the streak to end yesterday if nothing is logged yet today.
        let today = calendar.startOfDay(for: now)
        if byDay[today] == nil { offset = 1 }
        while offset < maxDays {
            let day = calendar.startOfDay(for: CareDates.adding(days: -offset, to: now, calendar: calendar))
            guard let e = byDay[day], predicate(e) else { break }
            count += 1
            offset += 1
        }
        return count
    }

    public static func daysSinceLast(_ entries: [EntryRecord], now: Date, calendar: Calendar) -> Int? {
        guard let last = entries.max(by: { $0.occurredAt < $1.occurredAt }) else { return nil }
        return CareDates.daysBetween(last.occurredAt, now, calendar: calendar)
    }

    public static func moodWord(_ value: Int) -> String {
        switch value {
        case ...1: "Low"
        case 2: "Meh"
        case 3: "Okay"
        case 4: "Good"
        default: "Great"
        }
    }

    public static func moodEmoji(_ value: Int) -> String {
        switch value {
        case ...1: "😞"
        case 2: "😕"
        case 3: "😐"
        case 4: "🙂"
        default: "😄"
        }
    }

    public static func weekdayAverages(_ entries: [EntryRecord], calendar: Calendar, value: (EntryRecord) -> Int?) -> [String: Double] {
        var sums: [String: (Double, Int)] = [:]
        for e in entries {
            guard let v = value(e) else { continue }
            let key = CareDates.weekdayName(e.occurredAt, calendar: calendar)
            let cur = sums[key] ?? (0, 0)
            sums[key] = (cur.0 + Double(v), cur.1 + 1)
        }
        return sums.mapValues { ($0.0 / Double(max(1, $0.1)) * 10).rounded() / 10 }
    }

    public static func signalID(_ module: ModuleID, _ kind: SignalKind, _ person: UUID, suffix: String = "") -> String {
        "\(module.rawValue).\(kind.rawValue).\(person.uuidString.prefix(8))\(suffix.isEmpty ? "" : ".\(suffix)")"
    }

    public static func plural(_ n: Int, _ singular: String, _ plural: String? = nil) -> String {
        n == 1 ? "\(n) \(singular)" : "\(n) \(plural ?? singular + "s")"
    }

    public static func litres(_ ml: Int) -> String {
        let l = Double(ml) / 1000
        return l == l.rounded() ? "\(Int(l)) L" : String(format: "%.1f L", l)
    }
}
