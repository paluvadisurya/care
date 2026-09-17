import SwiftUI
import Charts
import CareCore
import CareDesign
import CareData

public enum MoodUI: ModuleUI {
    public static let id: ModuleID = .mood

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        AnyView(MoodQuickLog(person: person))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(MoodDetail(person: person))
    }
}

struct MoodQuickLog: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var value = 4
    @State private var tag: String?
    @State private var note = ""

    var body: some View {
        SheetScaffold(title: "How is \(person.shortName)?", subtitle: "Mood", aura: person.aura, primaryTitle: "Log it") {
            store.addEntry(person: person.id, module: .mood, payload: MoodPayload(value: value, tag: tag, note: note.isEmpty ? nil : note))
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                PulseControl(value: $value)
                    .careCard(padding: CareSpace.sm + 2)
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Why, if you know")
                    ChipRow(items: MoodPayload.tags, selection: tag.map { [$0] } ?? [], label: { $0.capitalized }) { tag = tag == $0 ? nil : $0 }
                }
                CareField("Note", placeholder: "Optional", text: $note, axis: .vertical)
            }
        }
    }
}

struct MoodDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var pulse = 4
    @State private var showLog = false
    @State private var justSaved = false

    var entries: [EntryRecord] { store.entries(for: person.id, module: .mood) }

    var body: some View {
        let ctx = store.context(for: person, module: .mood)
        let trail = ModuleHelpers.trail(ctx.entries, days: 14, now: ctx.now, calendar: ctx.calendar, value: MoodLogic.value)
        let averages = ModuleHelpers.weekdayAverages(ctx.entries(in: CareDates.window(days: 60, endingAt: ctx.now)), calendar: ctx.calendar, value: MoodLogic.value)
        ModuleScreen(person: person, module: .mood, actionTitle: "Log with a note", action: { showLog = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Right now", trailing: "one drag")
                    PulseControl(value: $pulse)
                    PillButton("Save \(PulseControl.words[pulse - 1].lowercased())", style: .ghost, compact: true) {
                        store.addEntry(person: person.id, module: .mood, payload: MoodPayload(value: pulse))
                        justSaved.toggle()
                    }
                }
                .careCard(padding: CareSpace.sm + 2)
                .sensoryFeedback(.success, trigger: justSaved)

                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Last 14 days")
                    MoodStrip(values: trail, height: 44)
                }
                .careCard()

                if averages.count >= 3 {
                    VStack(alignment: .leading, spacing: CareSpace.xs) {
                        SectionLabel("By weekday", trailing: "60 days")
                        Chart {
                            ForEach(Calendar.care.shortWeekdaySymbols, id: \.self) { day in
                                if let v = averages[day] {
                                    BarMark(x: .value("Day", day), y: .value("Mood", v))
                                        .foregroundStyle(v <= 2.8 ? CareColor.coral : CareColor.violet)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .chartYScale(domain: 1...5)
                        .chartYAxis(.hidden)
                        .chartXAxis { AxisMarks { AxisValueLabel().font(CareFont.meta).foregroundStyle(CareColor.textMuted) } }
                        .frame(height: 110)
                    }
                    .careCard()
                }

                CardSection("History", trailing: ModuleHelpers.plural(entries.count, "check-in")) {
                    ForEach(entries.prefix(30)) { e in
                        if let m = e.decode(MoodPayload.self) {
                            CardRow(symbol: nil, title: "\(ModuleHelpers.moodEmoji(m.value))  \(ModuleHelpers.moodWord(m.value))",
                                    subtitle: [m.tag?.capitalized, m.note, e.occurredAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())].compactMap { $0 }.joined(separator: " · "))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showLog) { MoodQuickLog(person: person) }
    }
}
