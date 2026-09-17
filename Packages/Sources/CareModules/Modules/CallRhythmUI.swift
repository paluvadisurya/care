import SwiftUI
import CareCore
import CareDesign
import CareData

public enum CallRhythmUI: ModuleUI {
    public static let id: ModuleID = .callRhythm

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        AnyView(LogCallSheet(person: person))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(CallRhythmDetail(person: person))
    }
}

struct LogCallSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var minutes = 15
    @State private var note = ""

    var body: some View {
        SheetScaffold(title: "Called \(person.shortName)", subtitle: "Call rhythm", aura: person.aura, primaryTitle: "Log the call") {
            store.addEntry(person: person.id, module: .callRhythm, payload: CallPayload(durationMinutes: minutes, note: note.isEmpty ? nil : note))
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                SectionLabel("How long")
                ChipRow(items: [5, 15, 30, 60], selection: [minutes], label: { "\($0) min" }) { minutes = $0 }
                CareField("What came up", placeholder: "Optional", text: $note, axis: .vertical)
            }
        }
    }
}

struct CallRhythmDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showLog = false
    @State private var showSettings = false

    var body: some View {
        let ctx = store.context(for: person, module: .callRhythm)
        let settings = CallRhythmLogic.settings(ctx)
        let points = CallRhythmLogic.talkingPoints(ctx)
        ModuleScreen(person: person, module: .callRhythm, actionTitle: "Log a call", action: { showLog = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    HStack {
                        Text("Talking points").careType(.labelEmphasis).foregroundStyle(CareColor.intelligence)
                        Spacer()
                        Text("from mentions and events").careType(.footnote).foregroundStyle(CareColor.textMuted)
                    }
                    if points.isEmpty {
                        Text("Nothing saved yet. Mentions and upcoming events show up here.").careType(.callout).foregroundStyle(CareColor.textSecondary)
                    }
                    ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(i + 1)").careType(.metaEmphasis).foregroundStyle(CareColor.violet).frame(width: 14)
                            Text(p).careType(.callout).foregroundStyle(CareColor.textPrimary)
                        }
                    }
                    if let city = person.homeCity {
                        Text("Weather in \(city) arrives with WeatherKit in Phase 1.").careType(.footnote).foregroundStyle(CareColor.textMuted)
                    }
                }
                .careSurface(.hero)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rhythm").careType(.label).foregroundStyle(CareColor.textSecondary)
                        Text("Every \(settings.weekdayName), \(TimeOfDay(hour: settings.hour).label)").careType(.bodyEmphasis).foregroundStyle(CareColor.textPrimary)
                    }
                    Spacer()
                    PillButton("Change", style: .ghost, compact: true) { showSettings = true }
                }
                .careSurface(.tile)
                CardSection("Calls", trailing: ModuleHelpers.plural(ctx.entries.count, "call")) {
                    ForEach(ctx.entries.prefix(20)) { e in
                        let c = e.decode(CallPayload.self)
                        CardRow(symbol: "phone.fill", title: e.occurredAt.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)),
                                subtitle: [c?.durationMinutes.map { "\($0) min" }, c?.note].compactMap { $0 }.joined(separator: " · "), tint: ModuleAccent.color(for: .callRhythm))
                    }
                }
            }
        }
        .sheet(isPresented: $showLog) { LogCallSheet(person: person) }
        .sheet(isPresented: $showSettings) { CallRhythmSettingsSheet(person: person, settings: settings) }
    }
}

struct CallRhythmSettingsSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var weekday: Int
    @State private var hour: Int

    init(person: PersonRecord, settings: CallRhythmSettings) {
        self.person = person
        self.weekday = settings.weekday
        self.hour = settings.hour
    }

    var body: some View {
        SheetScaffold(title: "Call rhythm", subtitle: person.shortName, aura: person.aura, primaryTitle: "Save") {
            var p = person
            p.setSettings(CallRhythmSettings(weekday: weekday, hour: hour), for: .callRhythm)
            store.updatePerson(p)
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                SectionLabel("Day")
                ChipRow(items: Array(1...7), selection: [weekday], label: { CallRhythmSettings(weekday: $0).weekdayName }) { weekday = $0 }
                SectionLabel("Time")
                ChipRow(items: [9, 12, 17, 18, 19, 20, 21], selection: [hour], label: { TimeOfDay(hour: $0).label }) { hour = $0 }
            }
        }
    }
}
