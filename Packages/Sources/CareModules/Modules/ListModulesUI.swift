import SwiftUI
import CareCore
import CareDesign
import CareData

// Shared checklist, Promises and Wishlist share one shape: a list of small things with a done state.

public enum SharedChecklistUI: ModuleUI {
    public static let id: ModuleID = .sharedChecklist
    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? { AnyView(AddChecklistItemSheet(person: person, prefill: prefill)) }
    public static func detail(person: PersonRecord) -> AnyView { AnyView(SharedChecklistDetail(person: person)) }
}

public enum PromisesUI: ModuleUI {
    public static let id: ModuleID = .promises
    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? { AnyView(AddPromiseSheet(person: person, prefill: prefill)) }
    public static func detail(person: PersonRecord) -> AnyView { AnyView(PromisesDetail(person: person)) }
}

public enum WishlistUI: ModuleUI {
    public static let id: ModuleID = .wishlist
    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? { AnyView(AddWishSheet(person: person, prefill: prefill)) }
    public static func detail(person: PersonRecord) -> AnyView { AnyView(WishlistDetail(person: person)) }
}

// MARK: Shared checklist

struct SharedChecklistDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showAdd = false

    var body: some View {
        let entries = store.entries(for: person.id, module: .sharedChecklist)
        let items = entries.compactMap { e in e.decode(ChecklistItemPayload.self).map { (e, $0) } }
        let open = items.filter { !$0.1.done }
        let done = items.filter { $0.1.done }
        ModuleScreen(person: person, module: .sharedChecklist, actionTitle: "Add to the list", action: { showAdd = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                CardSection("Open", trailing: "\(open.count)") {
                    ForEach(open, id: \.0.id) { pair in
                        let e = pair.0
                        let item = pair.1
                        CardRow(title: item.text, subtitle: item.dueDate.map { "Due \(CareDates.relativeDays(from: .now, to: $0))" } ?? "Added \(CareDates.relativeDays(from: .now, to: e.occurredAt))",
                                tint: ModuleAccent.color(for: .sharedChecklist)) {
                            CheckToggle(isOn: Binding(get: { item.done }, set: { new in
                                var copy = item
                                copy.done = new
                                copy.doneAt = new ? .now : nil
                                copy.doneBy = new ? (store.me?.shortName ?? "You") : nil
                                store.updateEntry(e.id, payload: copy)
                            }))
                        }
                        .contextMenu { Button("Delete", systemImage: "trash", role: .destructive) { store.deleteEntry(e.id) } }
                        .swipeActions { Button(role: .destructive) { store.deleteEntry(e.id) } label: { Label("Delete", systemImage: "trash") } }
                    }
                    if open.isEmpty { Text("All clear. Nothing open between you.").careType(.callout).foregroundStyle(CareColor.textSecondary).padding(.horizontal, 4) }
                }
                if !done.isEmpty {
                    CardSection("Done", trailing: "\(done.count)") {
                        ForEach(done.prefix(15), id: \.0.id) { pair in
                            let e = pair.0
                            let item = pair.1
                            CardRow(title: item.text, subtitle: [item.doneBy, item.doneAt.map { $0.formatted(.dateTime.day().month(.abbreviated)) }].compactMap { $0 }.joined(separator: " · "), tint: CareColor.textMuted, isDone: true) {
                                CheckToggle(isOn: Binding(get: { true }, set: { new in
                                    var copy = item
                                    copy.done = new
                                    copy.doneAt = nil
                                    copy.doneBy = nil
                                    store.updateEntry(e.id, payload: copy)
                                }))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddChecklistItemSheet(person: person, prefill: nil) }
    }
}

struct AddChecklistItemSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var text: String
    @State private var hasDue = false
    @State private var due = CareDates.adding(days: 3, to: .now)

    init(person: PersonRecord, prefill: String?) {
        self.person = person
        self.text = prefill ?? ""
    }

    var body: some View {
        SheetScaffold(title: "With \(person.shortName)", subtitle: "Shared checklist", aura: person.aura, primaryTitle: "Add", primaryEnabled: !text.isEmpty) {
            store.addEntry(person: person.id, module: .sharedChecklist, payload: ChecklistItemPayload(text: text, dueDate: hasDue ? due : nil))
        } content: {
            VStack(spacing: CareSpace.sm) {
                CareField("What", placeholder: "Book the dentist", text: $text)
                CareToggleRow("Due date", isOn: $hasDue)
                if hasDue { CareDateRow("Due", date: $due, components: [.date]) }
            }
        }
    }
}

// MARK: Promises

struct PromisesDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showAdd = false

    var body: some View {
        let entries = store.entries(for: person.id, module: .promises)
        let items = entries.compactMap { e in e.decode(PromisePayload.self).map { (e, $0) } }
        ModuleScreen(person: person, module: .promises, actionTitle: "I promised…", action: { showAdd = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                CardSection("Open", trailing: "\(items.filter { !$0.1.kept }.count)") {
                    ForEach(items.filter { !$0.1.kept }, id: \.0.id) { pair in
                        let e = pair.0
                        let p = pair.1
                        CardRow(symbol: "hand.raised.fingers.spread", title: p.text,
                                subtitle: p.due.map { $0 < .now ? "Past due, \(CareDates.relativeDays(from: .now, to: $0))" : "Due \(CareDates.relativeDays(from: .now, to: $0))" } ?? "Made \(CareDates.relativeDays(from: .now, to: e.occurredAt))",
                                tint: (p.due.map { $0 < .now } ?? false) ? CareColor.attention : ModuleAccent.color(for: .promises)) {
                            PillButton("Kept", style: .ink, compact: true) {
                                var copy = p
                                copy.kept = true
                                copy.keptAt = .now
                                store.updateEntry(e.id, payload: copy)
                            }
                        }
                    }
                    if items.filter({ !$0.1.kept }).isEmpty { Text("Nothing open. Promises you keep build the kind of trust nothing else does.").careType(.callout).foregroundStyle(CareColor.textSecondary).padding(.horizontal, 4) }
                }
                let kept = items.filter { $0.1.kept }
                if !kept.isEmpty {
                    CardSection("Kept", trailing: "\(kept.count)") {
                        ForEach(kept.prefix(15), id: \.0.id) { pair in
                            let p = pair.1
                            CardRow(symbol: "checkmark.seal.fill", title: p.text, subtitle: p.keptAt.map { "Kept \($0.formatted(.dateTime.day().month(.abbreviated)))" }, tint: CareColor.positive, isDone: true)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddPromiseSheet(person: person, prefill: nil) }
    }
}

struct AddPromiseSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var text: String
    @State private var hasDue = true
    @State private var due = CareDates.adding(days: 7, to: .now)

    init(person: PersonRecord, prefill: String?) {
        self.person = person
        self.text = prefill ?? ""
    }

    var body: some View {
        SheetScaffold(title: "I promised \(person.shortName)…", subtitle: "Promise", aura: person.aura, primaryTitle: "Hold me to it", primaryEnabled: !text.isEmpty) {
            store.addEntry(person: person.id, module: .promises, payload: PromisePayload(text: text, due: hasDue ? due : nil))
        } content: {
            VStack(spacing: CareSpace.sm) {
                CareField("What", placeholder: "Book the pottery class", text: $text)
                CareToggleRow("By a date", isOn: $hasDue)
                if hasDue { CareDateRow("By", date: $due, components: [.date]) }
            }
        }
    }
}

// MARK: Wishlist

struct WishlistDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showAdd = false

    var body: some View {
        let entries = store.entries(for: person.id, module: .wishlist)
        let items = entries.compactMap { e in e.decode(WishlistItemPayload.self).map { (e, $0) } }
        let wants = items.filter { !$0.1.doNotBuy && !$0.1.purchased }
        let noBuy = items.filter { $0.1.doNotBuy }
        ModuleScreen(person: person, module: .wishlist, actionTitle: "Add a wish", action: { showAdd = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                CardSection("Wishes", trailing: "\(wants.count)") {
                    ForEach(wants, id: \.0.id) { pair in
                        let e = pair.0
                        let w = pair.1
                        CardRow(symbol: "gift", title: w.title, subtitle: [w.priceLabel, w.note, w.claimed ? "claimed" : nil].compactMap { $0 }.joined(separator: " · "), tint: ModuleAccent.color(for: .wishlist)) {
                            Menu {
                                Button(w.claimed ? "Unclaim" : "Claim it", systemImage: "hand.raised") { var c = w; c.claimed.toggle(); store.updateEntry(e.id, payload: c) }
                                Button("Bought", systemImage: "bag") { var c = w; c.purchased = true; store.updateEntry(e.id, payload: c) }
                                if let url = w.url.flatMap(URL.init(string:)) { Link(destination: url) { Label("Open link", systemImage: "safari") } }
                                Button("Delete", systemImage: "trash", role: .destructive) { store.deleteEntry(e.id) }
                            } label: {
                                Image(systemName: "ellipsis").foregroundStyle(CareColor.textMuted).frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("More")
                        }
                    }
                    if wants.isEmpty { Text("Share a product link into Care, or add one here.").careType(.callout).foregroundStyle(CareColor.textSecondary).padding(.horizontal, 4) }
                }
                if !noBuy.isEmpty {
                    CardSection("Please do not buy") {
                        ForEach(noBuy, id: \.0.id) { pair in
                            let w = pair.1
                            CardRow(symbol: "hand.thumbsdown", title: w.title, subtitle: w.note, tint: CareColor.attention)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddWishSheet(person: person, prefill: nil) }
    }
}

struct AddWishSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var title: String
    @State private var url = ""
    @State private var price = ""
    @State private var note = ""
    @State private var doNotBuy = false

    init(person: PersonRecord, prefill: String?) {
        self.person = person
        self.title = prefill ?? ""
    }

    var body: some View {
        SheetScaffold(title: "\(person.shortName) would love…", subtitle: "Wishlist", aura: person.aura, primaryTitle: "Add", primaryEnabled: !title.isEmpty) {
            store.addEntry(person: person.id, module: .wishlist, payload: WishlistItemPayload(title: title, url: url.isEmpty ? nil : url, price: Double(price), note: note.isEmpty ? nil : note, doNotBuy: doNotBuy))
        } content: {
            VStack(spacing: CareSpace.sm) {
                CareField("What", placeholder: "Pottery starter kit", text: $title)
                CareField("Link", placeholder: "https://", text: $url).keyboardType(.URL).textInputAutocapitalization(.never)
                CareField("Price, ₹", placeholder: "2499", text: $price).keyboardType(.decimalPad)
                CareField("Size, colour, notes", placeholder: "Optional", text: $note)
                CareToggleRow("Please do not buy", detail: "Things they would rather nobody gets them", isOn: $doNotBuy)
            }
        }
    }
}
