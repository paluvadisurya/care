import SwiftUI
import CareCore

/// Days and hours to a date in heavy tabular numerals. The unit sits at 40 percent size. Digits roll, never blink.
public struct Countdown: View {
    public var date: Date
    public var now: Date
    public var size: CGFloat
    public var showHours: Bool

    public init(to date: Date, now: Date = .now, size: CGFloat = 56, showHours: Bool = true) {
        self.date = date
        self.now = now
        self.size = size
        self.showHours = showHours
    }

    private var components: (days: Int, hours: Int, isPast: Bool) {
        let seconds = date.timeIntervalSince(now)
        let total = Int(abs(seconds))
        return (total / 86400, (total % 86400) / 3600, seconds < 0)
    }

    public var body: some View {
        let c = components
        HStack(alignment: .firstTextBaseline, spacing: size * 0.12) {
            if c.days == 0, showHours, !c.isPast {
                unit(value: c.hours, label: "h")
                unit(value: (Int(abs(date.timeIntervalSince(now))) % 3600) / 60, label: "m")
            } else {
                unit(value: c.days, label: "d")
                if showHours, c.days < 3, !c.isPast { unit(value: c.hours, label: "h") }
            }
        }
        .foregroundStyle(CareColor.textPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(c.isPast ? "\(c.days) days ago" : "\(c.days) days and \(c.hours) hours to go"))
    }

    private func unit(value: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(value)")
                .font(CareFont.display(size))
                .numeralStyle(size)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(CareFont.displayBold(size * 0.4, relativeTo: .title2))
                .foregroundStyle(CareColor.textSecondary)
        }
    }
}

/// A single big numeral with a unit, for heroes like "1 dose" or "0.5 L".
public struct BigNumeral: View {
    public var value: String
    public var unit: String
    public var size: CGFloat

    public init(value: String, unit: String, size: CGFloat = 56) {
        self.value = value
        self.unit = unit
        self.size = size
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(CareFont.display(size))
                .numeralStyle(size)
                .contentTransition(.numericText())
            Text(unit)
                .font(CareFont.displayBold(size * 0.36, relativeTo: .title2))
                .foregroundStyle(CareColor.textSecondary)
                .tracking(-0.3)
        }
        .foregroundStyle(CareColor.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}
