import SwiftUI
import Charts
import CareCore
import CareDesign
import CareData

public enum HydrationUI: ModuleUI {
    public static let id: ModuleID = .hydration

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        AnyView(HydrationQuickLog(person: person, prefillML: prefill.flatMap(Int.init)))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(HydrationDetail(person: person))
    }
}

struct HydrationQuickLog: View {
    @Environment(CareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let person: PersonRecord
    let prefillML: Int?
    @State private var added = 0

    var body: some View {
        let ctx = store.context(for: person, module: .hydration)
        let settings = HydrationLogic.settings(ctx)
        let total = HydrationLogic.total(on: ctx.now, ctx)
        ZStack {
            MeshBackground(aura: person.aura, intensity: 0.8)
            VStack(spacing: CareSpace.lg) {
                HStack {
                    Text("Water for \(person.shortName)").careType(.sheetTitle).displayTracking(26).foregroundStyle(CareColor.textPrimary)
                    Spacer()
                    IconButton("xmark", label: "Close") { dismiss() }
                }
                Ring(progress: Double(total) / Double(max(1, settings.targetML)), size: .jumbo, gradient: [CareColor.sky, CareColor.violet]) {
                    VStack(spacing: 2) {
                        Text(ModuleHelpers.litres(total)).careType(.screenTitle).numeralStyle(38).foregroundStyle(CareColor.textPrimary).contentTransition(.numericText())
                        Text("of \(ModuleHelpers.litres(settings.targetML))").careType(.caption).foregroundStyle(CareColor.textMuted)
                    }
                }
                HStack(spacing: CareSpace.xs) {
                    ForEach([settings.cupML, settings.cupML * 2, settings.cupML * 3], id: \.self) { ml in
                        PillButton("+\(ml) ml", style: .ghost) {
                            store.addEntry(person: person.id, module: .hydration, payload: HydrationPayload(milliliters: ml))
                            added += ml
                        }
                    }
                }
                .sensoryFeedback(.increase, trigger: added)
                Spacer()
            }
            .padding(CareSpace.gutter)
        }
        .task { if let prefillML, prefillML > 0 { store.addEntry(person: person.id, module: .hydration, payload: HydrationPayload(milliliters: prefillML)); added += prefillML } }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }
}

struct HydrationDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showLog = false

    struct DayTotal: Identifiable {
        nonisolated var id: Date { day }
        var day: Date
        var ml: Int
    }

    var body: some View {
        let ctx = store.context(for: person, module: .hydration)
        let settings = HydrationLogic.settings(ctx)
        let week: [DayTotal] = (0..<7).reversed().map { offset in
            let day = CareDates.adding(days: -offset, to: ctx.now, calendar: ctx.calendar)
            return DayTotal(day: ctx.calendar.startOfDay(for: day), ml: HydrationLogic.total(on: day, ctx))
        }
        ModuleScreen(person: person, module: .hydration, actionTitle: "Add water", action: { showLog = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                HStack(spacing: CareSpace.xs) {
                    ForEach([settings.cupML, settings.cupML * 2, 750], id: \.self) { ml in
                        PillButton("+\(ml)", style: .ghost, compact: true) {
                            store.addEntry(person: person.id, module: .hydration, payload: HydrationPayload(milliliters: ml))
                        }
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("This week", trailing: "target \(ModuleHelpers.litres(settings.targetML))")
                    Chart(week) { d in
                        BarMark(x: .value("Day", d.day, unit: .day), y: .value("ml", d.ml))
                            .foregroundStyle(d.ml >= settings.targetML ? CareColor.mint : CareColor.sky)
                            .cornerRadius(5)
                        RuleMark(y: .value("Target", settings.targetML)).foregroundStyle(CareColor.textMuted.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.narrow)).careType(.meta) } }
                    .chartYAxis(.hidden)
                    .frame(height: 120)
                }
                .careCard()
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Daily target")
                    HStack {
                        Text(ModuleHelpers.litres(settings.targetML)).careType(.tileValue).foregroundStyle(CareColor.textPrimary).contentTransition(.numericText())
                        Spacer()
                        Stepper("Target", value: Binding(get: { settings.targetML }, set: { new in
                            var p = person
                            p.setSettings(HydrationSettings(targetML: new, cupML: settings.cupML), for: .hydration)
                            store.updatePerson(p)
                        }), in: 1000...5000, step: 250).labelsHidden().tint(CareColor.ink)
                    }
                }
                .careCard()
            }
        }
        .sheet(isPresented: $showLog) { HydrationQuickLog(person: person, prefillML: nil) }
    }
}
