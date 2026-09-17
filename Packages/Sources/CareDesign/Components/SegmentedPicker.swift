import SwiftUI

/// A compact two or three way switch. The selected pill is one shape that slides between options rather than
/// two that fade, so the control reads as a physical thing moving.
public struct SegmentedPicker<Value: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var space
    public var options: [Value]
    public var label: (Value) -> String
    @Binding public var selection: Value

    public init(options: [Value], selection: Binding<Value>, label: @escaping (Value) -> String) {
        self.options = options
        _selection = selection
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button {
                    withAnimation(CareMotion.snappy(reduced: reduceMotion)) { selection = option }
                } label: {
                    Text(label(option))
                        .careType(.chipLabel)
                        .foregroundStyle(isOn ? CareColor.textPrimary : CareColor.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(CareColor.backgroundElevated)
                                    .careElevation(.resting)
                                    .matchedGeometryEffect(id: "segment", in: space)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.pressable(scale: 0.95))
                .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(3)
        .background(CareColor.chip, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A row of days above the timeline. Each day reserves the same width and shows whether anything is on it.
public struct DayStrip: View {
    public struct Day: Identifiable, Hashable {
        public var id: Date { date }
        public var date: Date
        public var count: Int
        public var isToday: Bool

        public init(date: Date, count: Int, isToday: Bool) {
            self.date = date
            self.count = count
            self.isToday = isToday
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var days: [Day]
    @Binding public var selection: Date

    public init(days: [Day], selection: Binding<Date>) {
        self.days = days
        _selection = selection
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(days) { day in
                    cell(day)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, CareSpace.gutter, for: .scrollContent)
        .animation(CareMotion.snappy(reduced: reduceMotion), value: selection)
    }

    private func cell(_ day: Day) -> some View {
        let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selection)
        return Button {
            selection = day.date
        } label: {
            VStack(spacing: 3) {
                Text(day.date.formatted(.dateTime.weekday(.narrow)))
                    .careType(.meta)
                    .foregroundStyle(isSelected ? CareColor.inkText.opacity(0.7) : CareColor.textMuted)
                Text(day.date.formatted(.dateTime.day()))
                    .font(CareFont.displayBold(17, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? CareColor.inkText : CareColor.textPrimary)
                Circle()
                    .fill(day.count > 0 ? (isSelected ? CareColor.inkText : CareColor.intelligence) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 46, height: 64)
            .background {
                RoundedRectangle(cornerRadius: CareRadius.inner)
                    .fill(isSelected ? AnyShapeStyle(CareColor.ink) : AnyShapeStyle(CareColor.chip))
            }
            .overlay {
                if day.isToday, !isSelected {
                    RoundedRectangle(cornerRadius: CareRadius.inner)
                        .strokeBorder(CareColor.ink, lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CareRadius.inner))
        }
        .buttonStyle(.pressable(scale: 0.94))
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(day.count == 0 ? "nothing" : "\(day.count) items")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
