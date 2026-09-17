import SwiftUI
import CareCore
import CareDesign
import CareData

public enum PetCareUI: ModuleUI {
    public static let id: ModuleID = .petCare

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        AnyView(PetCareLogSheet(person: person, prefillKind: prefill.flatMap(PetCareKind.init(rawValue:))))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(PetCareDetail(person: person))
    }
}

struct PetCareLogSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var kind: PetCareKind
    @State private var note = ""
    @State private var value = ""
    @State private var setNextDue = true
    @State private var nextDue: Date

    init(person: PersonRecord, prefillKind: PetCareKind?) {
        self.person = person
        let k = prefillKind ?? .vetVisit
        self.kind = k
        self.nextDue = CareDates.adding(days: k.defaultIntervalDays ?? 30, to: .now)
    }

    var body: some View {
        SheetScaffold(title: "\(person.shortName): \(kind.label.lowercased())", subtitle: "Pet care", aura: person.aura, primaryTitle: "Log it") {
            let v = Double(value)
            let due: Date? = (setNextDue && kind != .weight && kind != .medicine) ? nextDue : nil
            store.addEntry(person: person.id, module: .petCare, payload: PetCarePayload(kind: kind, note: note.isEmpty ? nil : note, nextDue: due, value: v))
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                ChipRow(items: PetCareKind.allCases, selection: [kind], label: { $0.label }) { k in
                    kind = k
                    if let d = k.defaultIntervalDays { nextDue = CareDates.adding(days: d, to: .now) }
                }
                if kind == .weight {
                    CareField("Weight, kg", placeholder: "6.0", text: $value).keyboardType(.decimalPad)
                } else if kind == .foodOrder {
                    CareField("Cost, ₹", placeholder: "2650", text: $value).keyboardType(.decimalPad)
                }
                CareField("Note", placeholder: kind == .vetVisit ? "All clear. Teeth to watch." : "Optional", text: $note, axis: .vertical)
                if kind != .weight && kind != .medicine {
                    CareToggleRow("Next one due", detail: kind.defaultIntervalDays.map { "Usually every \($0) days" }, isOn: $setNextDue)
                    if setNextDue { CareDateRow("Due", date: $nextDue, components: [.date]) }
                }
            }
        }
    }
}

struct PetCareDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showLog = false
    @State private var showSettings = false

    var body: some View {
        let ctx = store.context(for: person, module: .petCare)
        let settings = PetCareLogic.settings(ctx)
        let dues = PetCareLogic.dues(ctx)
        let weights = ctx.entries.compactMap { e -> Double? in
            guard let p = e.decode(PetCarePayload.self), p.kind == .weight else { return nil }
            return p.value
        }.reversed()
        ModuleScreen(person: person, module: .petCare, actionTitle: "Log care", action: { showLog = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                CardSection("Due next") {
                    ForEach(dues, id: \.kind) { d in
                        CardRow(symbol: d.kind.symbol, title: d.kind.label, subtitle: d.note ?? d.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                                tint: d.days <= 3 ? CareColor.attention : d.days <= 14 ? CareColor.upcoming : ModuleAccent.color(for: .petCare)) {
                            Text(d.days <= 0 ? "due" : "\(d.days)d").careType(.metaEmphasis).foregroundStyle(d.days <= 3 ? CareColor.attention : CareColor.textMuted)
                        }
                    }
                    if dues.isEmpty { Text("Log a vet visit, vaccine or food order and the next due date appears here.").careType(.callout).foregroundStyle(CareColor.textSecondary).padding(.horizontal, 4) }
                }
                if weights.count >= 2 {
                    VStack(alignment: .leading, spacing: CareSpace.xs) {
                        SectionLabel("Weight", trailing: weights.last.map { String(format: "%.1f kg now", $0) })
                        Sparkline(points: Array(weights), color: CareColor.honey, height: 56)
                    }
                    .careCard()
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(settings.breed.isEmpty ? settings.species : settings.breed)").careType(.bodyEmphasis).foregroundStyle(CareColor.textPrimary)
                        if let vet = settings.vetName { Text("Vet: \(vet)").careType(.caption).foregroundStyle(CareColor.textSecondary) }
                        if let food = settings.foodBrand { Text("Food: \(food), \(settings.foodDaysSupply) days a bag").careType(.caption).foregroundStyle(CareColor.textSecondary) }
                    }
                    Spacer()
                    PillButton("Edit", style: .ghost, compact: true) { showSettings = true }
                }
                .careCard(radius: CareRadius.tile, padding: CareSpace.sm + 2)
                CardSection("Log", trailing: ModuleHelpers.plural(ctx.entries.count, "entry", "entries")) {
                    ForEach(ctx.entries.prefix(25)) { e in
                        if let p = e.decode(PetCarePayload.self) {
                            CardRow(symbol: p.kind.symbol, title: p.kind == .weight ? String(format: "%.1f kg", p.value ?? 0) : p.kind.label,
                                    subtitle: [p.note, e.occurredAt.formatted(.dateTime.day().month(.abbreviated).year())].compactMap { $0 }.joined(separator: " · "), tint: CareColor.textMuted)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showLog) { PetCareLogSheet(person: person, prefillKind: nil) }
        .sheet(isPresented: $showSettings) { PetSettingsSheet(person: person, settings: settings) }
    }
}

struct PetSettingsSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var species: String
    @State private var breed: String
    @State private var vet: String
    @State private var food: String
    @State private var days: Int

    init(person: PersonRecord, settings: PetCareSettings) {
        self.person = person
        self.species = settings.species
        self.breed = settings.breed
        self.vet = settings.vetName ?? ""
        self.food = settings.foodBrand ?? ""
        self.days = settings.foodDaysSupply
    }

    var body: some View {
        SheetScaffold(title: "About \(person.shortName)", subtitle: "Pet care", aura: person.aura, primaryTitle: "Save") {
            var p = person
            p.setSettings(PetCareSettings(species: species, breed: breed, vetName: vet.isEmpty ? nil : vet, foodBrand: food.isEmpty ? nil : food, foodDaysSupply: days), for: .petCare)
            store.updatePerson(p)
        } content: {
            VStack(spacing: CareSpace.sm) {
                HStack(spacing: CareSpace.xs) {
                    CareField("Species", placeholder: "Dog", text: $species)
                    CareField("Breed", placeholder: "Shih Tzu", text: $breed)
                }
                CareField("Vet", placeholder: "Dr. Meera, Cessna Lifeline", text: $vet)
                CareField("Food", placeholder: "Royal Canin, 3 kg", text: $food)
                HStack {
                    Text("Days a bag lasts").careType(.label).foregroundStyle(CareColor.textSecondary)
                    Spacer()
                    Stepper("\(days)", value: $days, in: 5...120, step: 5).careType(.bodyEmphasis).tint(CareColor.ink)
                }
                .padding(.horizontal, CareSpace.sm).frame(minHeight: 46)
                .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
            }
        }
    }
}
