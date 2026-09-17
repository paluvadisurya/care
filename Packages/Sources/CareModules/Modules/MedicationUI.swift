import SwiftUI
import CareCore
import CareDesign
import CareData

public enum MedicationUI: ModuleUI {
    public static let id: ModuleID = .medication

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        AnyView(DoseSheet(person: person))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(MedicationDetail(person: person))
    }
}

struct DoseSlotRow: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    let slot: DoseSlot

    var body: some View {
        CardRow(symbol: "pills.fill", title: "\(slot.medicine.name), \(slot.medicine.dose)",
                subtitle: "\(CareDates.timeLabel(slot.scheduledAt))\(slot.medicine.withFood ? " · with food" : "")\(slot.medicine.givenBy.map { " · \($0) gives it" } ?? "")",
                tint: slot.state == .missed ? CareColor.attention : slot.state == .taken ? CareColor.positive : ModuleAccent.color(for: .medication),
                isDone: slot.state == .taken) {
            switch slot.state {
            case .taken:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(CareColor.positive).careSymbol(.xlarge, weight: .regular)
            case .skipped:
                Text("skipped").careType(.meta).foregroundStyle(CareColor.textMuted)
            default:
                HStack(spacing: 6) {
                    PillButton("Taken", style: .ink, compact: true) { log(.taken) }
                    PillButton("Skip", style: .ghost, compact: true) { log(.skipped) }
                }
            }
        }
    }

    func log(_ status: DoseStatus) {
        store.addEntry(person: person.id, module: .medication, payload: DosePayload(medicineID: slot.medicine.id, scheduledAt: slot.scheduledAt, status: status))
    }
}

struct DoseSheet: View {
    @Environment(CareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let person: PersonRecord

    var body: some View {
        let ctx = store.context(for: person, module: .medication)
        let slots = MedicationLogic.slots(on: ctx.now, ctx)
        ZStack {
            MeshBackground(aura: person.aura, intensity: 0.8)
            ScrollView {
                VStack(alignment: .leading, spacing: CareSpace.sm) {
                    HStack {
                        Text("\(person.shortName)'s doses today").careType(.sheetTitle).foregroundStyle(CareColor.textPrimary)
                        Spacer()
                        IconButton("xmark", label: "Close") { dismiss() }
                    }
                    ForEach(slots) { DoseSlotRow(person: person, slot: $0) }
                    if slots.isEmpty { Text("No medicines set up yet.").careType(.callout).foregroundStyle(CareColor.textSecondary) }
                }
                .padding(CareSpace.gutter)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CareRadius.hero)
    }
}

struct MedicationDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showAdd = false

    var body: some View {
        let ctx = store.context(for: person, module: .medication)
        let settings = MedicationLogic.settings(ctx)
        let today = MedicationLogic.slots(on: ctx.now, ctx)
        let adherence7 = MedicationLogic.adherence(days: 7, ctx)
        let adherence30 = MedicationLogic.adherence(days: 30, ctx)
        ModuleScreen(person: person, module: .medication, actionTitle: "Add a medicine", action: { showAdd = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                CardSection("Today") {
                    ForEach(today) { DoseSlotRow(person: person, slot: $0) }
                    if today.isEmpty { Text("Nothing scheduled today.").careType(.callout).foregroundStyle(CareColor.textSecondary) }
                }
                if let a7 = adherence7 {
                    HStack(spacing: CareSpace.sm) {
                        adherenceTile("7 days", a7)
                        adherenceTile("30 days", adherence30 ?? a7)
                    }
                }
                CardSection("Medicines", trailing: "\(settings.medicines.count)") {
                    ForEach(settings.medicines) { m in
                        CardRow(symbol: "pills", title: "\(m.name) · \(m.dose)",
                                subtitle: [m.times.map(\.label).joined(separator: ", "), m.purpose, m.refillDate.map { "refill \(CareDates.relativeDays(from: ctx.now, to: $0))" }].compactMap { $0 }.joined(separator: " · "),
                                tint: ModuleAccent.color(for: .medication)) {
                            if let r = m.refillDate, CareDates.daysBetween(ctx.now, r) <= 5 {
                                Text("refill").careType(.meta).foregroundStyle(CareColor.upcoming)
                            }
                        }
                        .contextMenu {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                var p = person
                                var s = settings
                                s.medicines.removeAll { $0.id == m.id }
                                p.setSettings(s, for: .medication)
                                store.updatePerson(p)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddMedicineSheet(person: person) }
    }

    func adherenceTile(_ label: String, _ value: Double) -> some View {
        HStack(spacing: CareSpace.sm) {
            Ring(bare: value, size: .row, gradient: [CareColor.mint, CareColor.sky])
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int((value * 100).rounded()))%").careType(.tileValue).foregroundStyle(CareColor.textPrimary)
                Text("taken, \(label)").careType(.caption).foregroundStyle(CareColor.textMuted)
            }
            Spacer(minLength: 0)
        }
        .careSurface(.row)
    }
}

struct AddMedicineSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var name = ""
    @State private var dose = ""
    @State private var purpose = ""
    @State private var givenBy = ""
    @State private var times: Set<Int> = [8]
    @State private var withFood = false
    @State private var hasRefill = false
    @State private var refill = CareDates.adding(days: 30, to: .now)

    static let slots: [(Int, String)] = [(8, "Morning 8am"), (13, "Noon 1pm"), (18, "Evening 6pm"), (20, "Night 8pm"), (22, "Bed 10pm")]

    var body: some View {
        SheetScaffold(title: "New medicine", subtitle: person.shortName, aura: person.aura, primaryTitle: "Add", primaryEnabled: !name.isEmpty && !times.isEmpty) {
            var p = person
            var s = MedicationLogic.settings(store.context(for: person, module: .medication))
            s.medicines.append(Medicine(name: name, dose: dose.isEmpty ? "1 tablet" : dose, times: times.sorted().map { TimeOfDay(hour: $0) }, withFood: withFood,
                                        purpose: purpose.isEmpty ? nil : purpose, refillDate: hasRefill ? refill : nil, givenBy: givenBy.isEmpty ? nil : givenBy))
            p.setSettings(s, for: .medication)
            store.updatePerson(p)
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                CareField("Name", placeholder: "Telmisartan", text: $name)
                HStack(spacing: CareSpace.xs) {
                    CareField("Dose", placeholder: "40 mg", text: $dose)
                    CareField("For", placeholder: "Blood pressure", text: $purpose)
                }
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Times")
                    ChipRow(items: Self.slots.map(\.0), selection: times, label: { h in Self.slots.first { $0.0 == h }?.1 ?? "\(h)" }) { h in
                        if times.contains(h) { times.remove(h) } else { times.insert(h) }
                    }
                }
                CareToggleRow("With food", isOn: $withFood)
                CareField("Who gives it", placeholder: "Mom, Ravi, themselves", text: $givenBy)
                CareToggleRow("Track refills", detail: "A nudge five days before it runs out", isOn: $hasRefill)
                if hasRefill { CareDateRow("Runs out on", date: $refill, components: [.date]) }
            }
        }
    }
}
