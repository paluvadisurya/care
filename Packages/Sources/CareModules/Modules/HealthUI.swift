import SwiftUI
import Charts
import CareCore
import CareDesign
import CareData

public enum HealthUI: ModuleUI {
    public static let id: ModuleID = .health

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        AnyView(HealthQuickLog(person: person, prefill: prefill))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(HealthDetail(person: person))
    }
}

struct HealthQuickLog: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    let prefillKind: ReadingKind?
    @State private var state: HealthState = .allGood
    @State private var symptoms: Set<String> = []
    @State private var readingKind: ReadingKind?
    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var value = ""
    @State private var fasting = true
    @State private var note = ""

    init(person: PersonRecord, prefill: String?) {
        self.person = person
        self.prefillKind = prefill.flatMap { p in ReadingKind.allCases.first { $0.label == p } }
    }

    var reading: HealthReading? {
        guard let readingKind else { return nil }
        switch readingKind {
        case .bloodPressure:
            guard let s = Int(systolic), let d = Int(diastolic) else { return nil }
            return HealthReading(kind: .bloodPressure, systolic: s, diastolic: d)
        case .bloodSugar:
            guard let v = Double(value) else { return nil }
            return HealthReading(kind: .bloodSugar, value: v, unit: "mg/dL", context: fasting ? "fasting" : "post meal")
        case .weight:
            guard let v = Double(value) else { return nil }
            return HealthReading(kind: .weight, value: v, unit: "kg")
        case .temperature:
            guard let v = Double(value) else { return nil }
            return HealthReading(kind: .temperature, value: v, unit: "°C")
        }
    }

    var body: some View {
        SheetScaffold(title: "\(person.shortName)'s health", subtitle: "Health · private", aura: person.aura, primaryTitle: "Log it") {
            store.addEntry(person: person.id, module: .health, payload: HealthPayload(state: state, symptoms: Array(symptoms), note: note.isEmpty ? nil : note, reading: reading))
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Overall")
                    ChipRow(items: HealthState.allCases, selection: [state], label: { $0.label }) { state = $0 }
                }
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Symptoms")
                    ChipRow(items: HealthPayload.symptomChips, selection: symptoms, label: { $0.capitalized }) { s in
                        if symptoms.contains(s) { symptoms.remove(s) } else { symptoms.insert(s) }
                    }
                }
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Reading")
                    ChipRow(items: ReadingKind.allCases, selection: readingKind.map { [$0] } ?? [], label: { $0.label }) { readingKind = readingKind == $0 ? nil : $0 }
                    if readingKind == .bloodPressure {
                        HStack(spacing: CareSpace.xs) {
                            CareField("Systolic", placeholder: "128", text: $systolic).keyboardType(.numberPad)
                            CareField("Diastolic", placeholder: "84", text: $diastolic).keyboardType(.numberPad)
                        }
                    } else if let readingKind {
                        CareField(readingKind.label, placeholder: readingKind == .bloodSugar ? "112" : readingKind == .weight ? "72.5" : "37.0", text: $value).keyboardType(.decimalPad)
                        if readingKind == .bloodSugar {
                            ChipRow(items: [true, false], selection: [fasting], label: { $0 ? "Fasting" : "After a meal" }) { fasting = $0 }
                        }
                    }
                }
                CareField("Note", placeholder: "Optional", text: $note, axis: .vertical)
            }
        }
        .task { if readingKind == nil { readingKind = prefillKind } }
    }
}

struct HealthDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showLog = false

    var entries: [EntryRecord] { store.entries(for: person.id, module: .health) }

    struct BPPoint: Identifiable {
        var id: UUID
        var date: Date
        var systolic: Int
        var diastolic: Int
    }

    var bpPoints: [BPPoint] {
        entries.compactMap { e in
            guard let r = e.decode(HealthPayload.self)?.reading, r.kind == .bloodPressure, let s = r.systolic, let d = r.diastolic else { return nil }
            return BPPoint(id: e.id, date: e.occurredAt, systolic: s, diastolic: d)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ModuleScreen(person: person, module: .health, actionTitle: "Log health", action: { showLog = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                if bpPoints.count >= 2 {
                    VStack(alignment: .leading, spacing: CareSpace.xs) {
                        SectionLabel("Blood pressure", trailing: "\(bpPoints.count) readings")
                        Chart {
                            RuleMark(y: .value("Upper", 140)).foregroundStyle(CareColor.coral.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            ForEach(bpPoints) { p in
                                LineMark(x: .value("Date", p.date), y: .value("Systolic", p.systolic), series: .value("Kind", "Systolic"))
                                    .foregroundStyle(CareColor.violet).interpolationMethod(.catmullRom)
                                PointMark(x: .value("Date", p.date), y: .value("Systolic", p.systolic))
                                    .foregroundStyle(p.systolic >= 140 ? CareColor.coral : CareColor.violet)
                                LineMark(x: .value("Date", p.date), y: .value("Diastolic", p.diastolic), series: .value("Kind", "Diastolic"))
                                    .foregroundStyle(CareColor.sky).interpolationMethod(.catmullRom)
                            }
                        }
                        .chartYScale(domain: 60...160)
                        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 3)) { AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(CareType.meta.font) } }
                        .chartYAxis { AxisMarks(values: [80, 120, 140]) { AxisGridLine().foregroundStyle(CareColor.separator); AxisValueLabel().font(CareType.meta.font) } }
                        .frame(height: 150)
                        Text("Dashed line at 140. A reading above it is worth a recheck, not a diagnosis.")
                            .careType(.meta).foregroundStyle(CareColor.textMuted)
                    }
                    .careCard()
                }
                CardSection("Log", trailing: "private to you") {
                    ForEach(entries.prefix(40)) { e in
                        if let h = e.decode(HealthPayload.self) {
                            CardRow(symbol: h.reading?.kind == .bloodPressure ? "waveform.path.ecg" : h.reading?.kind == .bloodSugar ? "drop.halffull" : "heart.text.square",
                                    title: h.reading?.label ?? h.state.label,
                                    subtitle: [h.symptoms.isEmpty ? nil : h.symptoms.joined(separator: ", "), h.note, e.occurredAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())].compactMap { $0 }.joined(separator: " · "),
                                    tint: h.reading?.isAboveUsualRange == true || h.state == .notGood ? CareColor.attention : ModuleAccent.color(for: .health)) {
                                if h.reading?.isAboveUsualRange == true {
                                    Text("above range").careType(.meta).foregroundStyle(CareColor.attention)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showLog) { HealthQuickLog(person: person, prefill: nil) }
    }
}
