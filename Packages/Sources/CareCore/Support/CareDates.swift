import Foundation

public extension Calendar {
    /// The calendar Care uses everywhere. Gregorian, current locale and time zone.
    static var care: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale.current
        c.timeZone = TimeZone.current
        return c
    }
}

/// Date helpers shared by modules, ranking and the intelligence layer.
public enum CareDates {
    public static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    public static func shortDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM-dd"
        return f.string(from: date)
    }

    public static func weekdayName(_ date: Date, calendar: Calendar = .care) -> String {
        let idx = calendar.component(.weekday, from: date) - 1
        return calendar.shortWeekdaySymbols[max(0, min(6, idx))]
    }

    public static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .care) -> Int {
        let a = calendar.startOfDay(for: from)
        let b = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    public static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar = .care) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    public static func at(hour: Int, minute: Int = 0, on day: Date, calendar: Calendar = .care) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: day)) ?? day
    }

    public static func adding(days: Int, to date: Date, calendar: Calendar = .care) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    public static func adding(hours: Int, to date: Date, calendar: Calendar = .care) -> Date {
        calendar.date(byAdding: .hour, value: hours, to: date) ?? date
    }

    public static func hour(of date: Date, calendar: Calendar = .care) -> Int {
        calendar.component(.hour, from: date)
    }

    /// "in 12 days", "tomorrow", "today", "3 days ago"
    public static func relativeDays(from now: Date, to date: Date, calendar: Calendar = .care) -> String {
        let d = daysBetween(now, date, calendar: calendar)
        switch d {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case 2...: return "in \(d) days"
        default: return "\(-d) days ago"
        }
    }

    /// "6h ago", "just now", "2d ago"
    public static func relativeShort(from now: Date, to past: Date) -> String {
        let s = Int(now.timeIntervalSince(past))
        if s < 90 { return "just now" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        if h < 24 { return "\(h)h ago" }
        let d = h / 24
        return "\(d)d ago"
    }

    public static func timeLabel(_ date: Date, calendar: Calendar = .care) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale.current
        f.dateFormat = "h:mm a"
        return f.string(from: date).lowercased()
    }

    /// A window ending now and starting `days` ago.
    public static func window(days: Int, endingAt now: Date, calendar: Calendar = .care) -> DateInterval {
        DateInterval(start: adding(days: -days, to: now, calendar: calendar), end: now)
    }

    /// Whether the hour falls inside quiet hours like ["22:00","07:00"].
    public static func isQuiet(_ date: Date, quietHours: [String], calendar: Calendar = .care) -> Bool {
        guard quietHours.count == 2,
              let start = Int(quietHours[0].prefix(2)), let end = Int(quietHours[1].prefix(2)) else { return false }
        let h = calendar.component(.hour, from: date)
        if start > end { return h >= start || h < end }   // overnight
        return h >= start && h < end
    }
}
