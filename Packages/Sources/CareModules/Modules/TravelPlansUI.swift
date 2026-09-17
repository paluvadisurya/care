import SwiftUI
import CareCore
import CareDesign
import CareData

public enum TravelPlansUI: ModuleUI {
    public static let id: ModuleID = .travelPlans

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(TravelPlansDetail(person: person))
    }
}

struct TravelPlansDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showAdd = false
    @State private var newItem = ""

    var body: some View {
        let ctx = store.context(for: person, module: .travelPlans)
        let trips = TravelPlansLogic.trips(ctx).sorted { $0.trip.from < $1.trip.from }
        let next = TravelPlansLogic.nextTrip(ctx)
        ModuleScreen(person: person, module: .travelPlans, actionTitle: "Plan a trip", action: { showAdd = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                if let next {
                    VStack(alignment: .leading, spacing: CareSpace.sm) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(next.trip.travelers.isEmpty ? "Trip" : next.trip.travelers.joined(separator: " and ")).careType(.labelEmphasis).foregroundStyle(CareColor.textSecondary)
                                Text(next.trip.destination).careType(.screenTitle).foregroundStyle(CareColor.textPrimary)
                                Text("\(next.trip.from.formatted(.dateTime.day().month(.abbreviated))) to \(next.trip.to.formatted(.dateTime.day().month(.abbreviated)))").careType(.caption).foregroundStyle(CareColor.textMuted)
                            }
                            Spacer()
                            Countdown(to: next.trip.from, now: ctx.now, size: .large, showsHours: false)
                        }
                        if let notes = next.trip.notes { Text(notes).careType(.callout).foregroundStyle(CareColor.textSecondary) }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Packing").careType(.label).foregroundStyle(CareColor.textSecondary)
                                Spacer()
                                Text("\(next.trip.packedCount) of \(next.trip.packing.count)").careType(.meta).foregroundStyle(CareColor.textMuted)
                            }
                            ForEach(next.trip.packing) { item in
                                HStack {
                                    CheckToggle(isOn: Binding(get: { item.done }, set: { new in
                                        var t = next.trip
                                        if let i = t.packing.firstIndex(where: { $0.id == item.id }) { t.packing[i].done = new }
                                        store.updateEntry(next.entry.id, payload: t)
                                    }))
                                    Text(item.text).careType(.body).foregroundStyle(item.done ? CareColor.textMuted : CareColor.textPrimary).strikethrough(item.done)
                                    Spacer()
                                }
                            }
                            HStack {
                                TextField("Add to the list", text: $newItem).careType(.body)
                                    .onSubmit { addItem(to: next) }
                                IconButton("plus", label: "Add item") { addItem(to: next) }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .careSurface(.hero)
                }
                if trips.count > 1 || next == nil {
                    CardSection("All trips", trailing: "\(trips.count)") {
                        ForEach(trips, id: \.entry.id) { t in
                            CardRow(symbol: "airplane", title: t.trip.destination, subtitle: "\(t.trip.from.formatted(.dateTime.day().month(.abbreviated).year())) · \(t.trip.travelers.joined(separator: ", "))", tint: ModuleAccent.color(for: .travelPlans))
                                .contextMenu { Button("Delete", systemImage: "trash", role: .destructive) { store.deleteEntry(t.entry.id) } }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddTripSheet(person: person) }
    }

    func addItem(to next: (entry: EntryRecord, trip: TripPayload)) {
        let text = newItem.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        var t = next.trip
        t.packing.append(PackingItem(text: text))
        store.updateEntry(next.entry.id, payload: t)
        newItem = ""
    }
}

struct AddTripSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var destination = ""
    @State private var from = CareDates.adding(days: 14, to: .now)
    @State private var to = CareDates.adding(days: 17, to: .now)
    @State private var travelers = ""
    @State private var notes = ""

    var body: some View {
        SheetScaffold(title: "Where to?", subtitle: person.shortName, aura: person.aura, primaryTitle: "Plan it", primaryEnabled: !destination.isEmpty) {
            let who = travelers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let packing = ["Chargers", "Medicines", "Documents", "Toiletries"].map { PackingItem(text: $0) }
            store.addEntry(person: person.id, module: .travelPlans, at: from, payload: TripPayload(destination: destination, from: from, to: max(from, to), travelers: who, packing: packing, notes: notes.isEmpty ? nil : notes))
        } content: {
            VStack(spacing: CareSpace.sm) {
                CareField("Destination", placeholder: "Coorg", text: $destination)
                CareDateRow("From", date: $from, components: [.date])
                CareDateRow("To", date: $to, components: [.date])
                CareField("Who is going", placeholder: "Comma separated", text: $travelers)
                CareField("Notes", placeholder: "Optional", text: $notes, axis: .vertical)
            }
        }
    }
}
