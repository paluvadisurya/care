import SwiftUI
import CareCore

/// Days and hours to a date, in heavy tabular numerals with the unit at a fraction of the size.
/// Digits roll rather than blink, so a countdown ticking over reads as the same number changing.
public struct Countdown: View {
    public enum Size: Sendable {
        case hero, large, compact

        var role: CareType {
            switch self {
            case .hero: .heroNumeral
            case .large: .numeral
            case .compact: .numeralCompact
            }
        }

        var unitRatio: CGFloat { 0.4 }
    }

    public var date: Date
    public var now: Date
    public var size: Size
    public var showsHours: Bool

    public init(to date: Date, now: Date = .now, size: Size = .hero, showsHours: Bool = true) {
        self.date = date
        self.now = now
        self.size = size
        self.showsHours = showsHours
    }

    private var parts: (days: Int, hours: Int, minutes: Int, isPast: Bool) {
        let seconds = date.timeIntervalSince(now)
        let total = Int(abs(seconds))
        return (total / 86400, (total % 86400) / 3600, (total % 3600) / 60, seconds < 0)
    }

    public var body: some View {
        let p = parts
        HStack(alignment: .firstTextBaseline, spacing: size.role.size * 0.1) {
            if p.days == 0, showsHours, !p.isPast {
                unit(p.hours, "h")
                unit(p.minutes, "m")
            } else {
                unit(p.days, "d")
                if showsHours, p.days < 3, !p.isPast { unit(p.hours, "h") }
            }
        }
        .foregroundStyle(CareColor.textPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(p.isPast ? "\(p.days) days ago" : "\(p.days) days and \(p.hours) hours to go"))
    }

    private func unit(_ value: Int, _ suffix: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(value)")
                .careType(size.role)
                .contentTransition(.numericText(value: Double(value)))
            Text(suffix)
                .font(CareFont.displayBold(size.role.size * size.unitRatio, relativeTo: .title3))
                .foregroundStyle(CareColor.textSecondary)
        }
    }
}

/// A single big numeral with a unit, for heroes like "1 dose" or "0.5 L".
public struct BigNumeral: View {
    public var value: String
    public var unit: String
    public var size: Countdown.Size
    public var tone: Tone

    public init(value: String, unit: String, size: Countdown.Size = .hero, tone: Tone = .neutral) {
        self.value = value
        self.unit = unit
        self.size = size
        self.tone = tone
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .careType(size.role)
                .foregroundStyle(tone == .attention ? CareColor.attention : CareColor.textPrimary)
                .rollingNumber()
            Text(unit)
                .font(CareFont.displayBold(size.role.size * 0.36, relativeTo: .title3))
                .foregroundStyle(CareColor.textSecondary)
                .tracking(-0.3)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(unit)")
    }
}

/// One big word, for heroes whose state is not a number: "Low ×3", "Call day", "Due now".
public struct BigWord: View {
    public var text: String
    public var tone: Tone

    public init(_ text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .careType(.numeral)
            .foregroundStyle(tone == .attention ? CareColor.attention : CareColor.textPrimary)
    }
}
