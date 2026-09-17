import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Everyone's day on one rail. Items from every module merge into a single line, coloured by whose they are,
/// with a now marker that moves on its own.
struct TimelineScreen: View {
    @Environment(CareStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = .day
    @State private var now = Date()

    enum Mode: String, CaseIterable { case day = "Day", week = "Week" }

    private var day: Date { router.timelineDay }
    private var items: [TimelineItem] { store.timelineItems(day: day, now: now) }

    private var days: [Date] {
        let start = Calendar.care.startOfDay(for: CareDates.adding(days: -2, to: now))
        return (0..<12).map { CareDates.adding(days: $0, to: start) }
    }

    var body: some View {
        @Bindable var router = router
        ZStack {
            MeshBackground(aura: store.me?.aura ?? .skyViolet, intensity: 0.8)
            ScrollView {
                VStack(alignment: .leading, spacing: CareLayout.sectionGap) {
                    header
                        .careGutter()
                        .staggeredEntrance(index: 0)

                    DayStrip(days: days.map { date in
                        DayStrip.Day(date: date,
                                     count: store.timelineItems(day: date, now: now).count,
                                     isToday: CareDates.isSameDay(date, now))
                    }, selection: $router.timelineDay)
                    .staggeredEntrance(index: 1)

                    // Day and week are two readings of the same data, so they slide rather than cut.
                    Group {
                        if mode == .day { dayView } else { weekView }
                    }
                    .careGutter()
                    .staggeredEntrance(index: 2)
                    .careDirectionalTransition(mode == .day ? .backward : .forward)
                    .animation(CareMotion.standard(reduced: reduceMotion), value: mode)
                    .id(mode)
                }
                .padding(.top, CareSpace.xs)
                .padding(.bottom, CareLayout.scrollBottomInset)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: CareSpace.sm) {
            ScreenTitle(eyebrow: "Timeline",
                        lead: CareDates.isSameDay(day, now) ? "Today" : day.formatted(.dateTime.weekday(.wide)),
                        accent: CareDates.isSameDay(day, now) ? nil : day.formatted(.dateTime.day().month(.abbreviated)))
            Spacer(minLength: 0)
            SegmentedPicker(options: Mode.allCases, selection: $mode) { $0.rawValue }
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 8 }
        }
    }

    @ViewBuilder
    private var dayView: some View {
        if items.isEmpty {
            EmptyState(symbol: "sun.horizon",
                       title: "A clear day",
                       message: "Nothing scheduled for anyone. Add an event from a person's profile.",
                       aura: store.me?.aura)
                .careSurface(.hero)
        } else {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                TimelineRail(items: items, now: now, auraFor: { id in id.flatMap { store.person($0)?.aura } }) { item in
                    if let link = item.link { router.handle(link) }
                }
                Text("Apple Calendar and Reminders merge into this rail when the integrations arrive in Phase 1.")
                    .careType(.footnote)
                    .foregroundStyle(CareColor.textMuted)
                    .padding(.horizontal, CareSpace.xxs)
            }
        }
    }

    private var weekView: some View {
        VStack(alignment: .leading, spacing: CareLayout.stackGap) {
            ForEach(Array(days.dropFirst(2).enumerated()), id: \.element) { index, date in
                WeekDayCard(date: date,
                            items: store.timelineItems(day: date, now: now),
                            auraFor: { id in id.flatMap { store.person($0)?.aura } }) {
                    router.timelineDay = date
                    withAnimation(CareMotion.standard) { mode = .day }
                }
                .staggeredEntrance(index: index)
            }
        }
    }
}

private struct WeekDayCard: View {
    var date: Date
    var items: [TimelineItem]
    var auraFor: (UUID?) -> Aura?
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: CareSpace.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .careType(.labelEmphasis)
                        .foregroundStyle(CareColor.textSecondary)
                    Spacer(minLength: CareSpace.xs)
                    Text(items.isEmpty ? "clear" : ModuleHelpers.plural(items.count, "item"))
                        .careType(.meta)
                        .foregroundStyle(CareColor.textMuted)
                }
                ForEach(items.prefix(4)) { item in
                    HStack(spacing: CareSpace.xs) {
                        Circle()
                            .fill(auraFor(item.personID)?.gradient
                                  ?? LinearGradient(colors: [CareColor.ink], startPoint: .top, endPoint: .bottom))
                            .frame(width: 7, height: 7)
                        Text(item.title)
                            .careType(.callout)
                            .foregroundStyle(CareColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: CareSpace.xs)
                        Text(item.isAllDay ? "all day" : CareDates.timeLabel(item.start))
                            .careType(.meta)
                            .foregroundStyle(CareColor.textMuted)
                    }
                }
                if items.count > 4 {
                    Text("and \(items.count - 4) more")
                        .careType(.meta)
                        .foregroundStyle(CareColor.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .careSurface(.tile)
        }
        .buttonStyle(.pressable(scale: 0.98))
    }
}
