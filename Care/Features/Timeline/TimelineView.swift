import SwiftUI
import CareCore
import CareDesign
import CareData
import CareModules

/// Structured-style day rail with a week strip. Items from every module merge into one line, coloured by aura.
struct TimelineView: View {
    @Environment(CareStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var mode: Mode = .day
    @State private var now = Date()

    enum Mode: String, CaseIterable { case day = "Day", week = "Week" }

    private var day: Date { router.timelineDay }
    private var items: [TimelineItem] { store.timelineItems(day: day, now: now) }

    var body: some View {
        @Bindable var router = router
        ZStack {
            MeshBackground(aura: store.me?.aura ?? .skyViolet, intensity: 0.8)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.md) {
                    HStack(alignment: .firstTextBaseline) {
                        ScreenTitle(eyebrow: "Timeline", lead: CareDates.isSameDay(day, now) ? "Today" : day.formatted(.dateTime.weekday(.wide)),
                                    accent: CareDates.isSameDay(day, now) ? nil : day.formatted(.dateTime.day().month(.abbreviated)))
                        Spacer()
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                    }
                    .padding(.top, CareSpace.xs)
                    weekStrip
                    if mode == .day {
                        if items.isEmpty {
                            EmptyState(symbol: "calendar", title: "A clear day", message: "Nothing scheduled for anyone. Add an event from a person's profile.")
                                .careCard(radius: CareRadius.hero, strong: true)
                        } else {
                            TimelineRail(items: items, now: now, auraFor: { id in id.flatMap { store.person($0)?.aura } }) { item in
                                if let link = item.link { router.handle(link) }
                            }
                        }
                        Text("Apple Calendar and Reminders merge into this rail when the integrations arrive in Phase 1.")
                            .font(CareFont.meta).foregroundStyle(CareColor.textMuted).padding(.horizontal, 4)
                    } else {
                        weekList
                    }
                }
                .padding(.horizontal, CareSpace.gutter)
                .padding(.bottom, CareSpace.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private var weekDays: [Date] {
        let start = Calendar.care.startOfDay(for: CareDates.adding(days: -1, to: now))
        return (0..<10).map { CareDates.adding(days: $0, to: start) }
    }

    private var weekStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { d in
                    let isSel = CareDates.isSameDay(d, day)
                    let count = store.timelineItems(day: d, now: now).count
                    Button { router.timelineDay = d } label: {
                        VStack(spacing: 3) {
                            Text(d.formatted(.dateTime.weekday(.narrow))).font(CareFont.meta).foregroundStyle(isSel ? CareColor.inkText.opacity(0.7) : CareColor.textMuted)
                            Text(d.formatted(.dateTime.day())).font(CareFont.displayBold(17, relativeTo: .body)).foregroundStyle(isSel ? CareColor.inkText : CareColor.textPrimary)
                            Circle().fill(count > 0 ? (isSel ? CareColor.inkText : CareColor.violet) : .clear).frame(width: 4, height: 4)
                        }
                        .frame(width: 46, height: 62)
                        .background(isSel ? CareColor.ink : CareColor.chip, in: RoundedRectangle(cornerRadius: CareRadius.inner + 2))
                        .overlay {
                            if CareDates.isSameDay(d, now), !isSel { RoundedRectangle(cornerRadius: CareRadius.inner + 2).strokeBorder(CareColor.ink, lineWidth: 1.5) }
                        }
                    }
                    .buttonStyle(.pressable(scale: 0.94))
                    .accessibilityLabel(d.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var weekList: some View {
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            ForEach(weekDays.dropFirst(), id: \.self) { d in
                let dayItems = store.timelineItems(day: d, now: now)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(d.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))).font(CareFont.labelSemi).foregroundStyle(CareColor.textSecondary)
                        Spacer()
                        Text(dayItems.isEmpty ? "clear" : ModuleHelpers.plural(dayItems.count, "item")).font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                    }
                    ForEach(dayItems.prefix(4)) { item in
                        HStack(spacing: 8) {
                            Circle().fill((item.personID.flatMap { store.person($0)?.aura }?.gradient) ?? LinearGradient(colors: [CareColor.ink], startPoint: .top, endPoint: .bottom)).frame(width: 8, height: 8)
                            Text(item.title).font(CareFont.callout).foregroundStyle(CareColor.textPrimary).lineLimit(1)
                            Spacer()
                            Text(item.isAllDay ? "all day" : CareDates.timeLabel(item.start)).font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                        }
                    }
                }
                .careCard(radius: CareRadius.tile, padding: CareSpace.sm + 2)
                .onTapGesture { router.timelineDay = d; mode = .day }
            }
        }
    }
}
