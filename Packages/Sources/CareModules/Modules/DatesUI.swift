import SwiftUI
import CareCore
import CareDesign
import CareData

public enum DatesUI: ModuleUI {
    public static let id: ModuleID = .dates

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(DatesDetail(person: person))
    }
}

struct DatesDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showAdd = false
    @State private var giftFor: EventRecord?

    var body: some View {
        let ctx = store.context(for: person, module: .dates)
        let upcoming = DatesLogic.upcoming(ctx)
        ModuleScreen(person: person, module: .dates, actionTitle: "Add a date", action: { showAdd = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                if let next = upcoming.first {
                    VStack(alignment: .leading, spacing: CareSpace.xs) {
                        HStack {
                            Text(next.event.title).font(CareFont.labelSemi).foregroundStyle(CareColor.textSecondary)
                            Spacer()
                            Text(next.date.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(CareFont.meta).foregroundStyle(CareColor.textMuted)
                        }
                        Countdown(to: next.date, now: ctx.now, size: 64, showHours: next.days < 3)
                        if let y = next.years, y > 0 {
                            Text("The \(DatesLogic.ordinal(y)).\(DatesLogic.lastGift(for: next.event, ctx).map { " Last year: \($0.gift)." } ?? " No gift logged last year.")")
                                .font(CareFont.callout).foregroundStyle(CareColor.textSecondary)
                        }
                        HStack(spacing: CareSpace.xs) {
                            PillButton("Log a gift", style: .ink, compact: true) { giftFor = next.event }
                            if person.isEnabled(.wishlist) {
                                NavigationLink(value: ModuleRoute(personID: person.id, module: .wishlist)) {
                                    Text("Wishlist").font(CareFont.chip).foregroundStyle(CareColor.textPrimary).padding(.horizontal, CareSpace.sm).frame(height: 36).background(CareColor.chip, in: Capsule())
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }
                    .careCard(radius: CareRadius.hero, padding: CareSpace.md + 2, strong: true)
                }
                CardSection("All dates", trailing: "\(upcoming.count)") {
                    ForEach(upcoming, id: \.event.id) { u in
                        CardRow(symbol: u.event.category.symbol, title: u.event.title,
                                subtitle: "\(u.date.formatted(.dateTime.day().month(.abbreviated)))\(u.years.map { $0 > 0 ? " · the \(DatesLogic.ordinal($0))" : "" } ?? "")",
                                tint: ModuleAccent.color(for: .dates)) {
                            Text(u.days == 0 ? "today" : "\(u.days)d").font(CareFont.monoMedium(12)).foregroundStyle(u.days <= 14 ? CareColor.upcoming : CareColor.textMuted)
                        }
                        .contextMenu {
                            Button("Log a gift", systemImage: "gift") { giftFor = u.event }
                            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteEvent(u.event.id) }
                        }
                    }
                }
                let gifts = store.entries(for: person.id, module: .dates).compactMap { e in e.decode(GiftPayload.self) }
                if !gifts.isEmpty {
                    CardSection("Gift history") {
                        ForEach(gifts, id: \.self) { g in
                            CardRow(symbol: "gift", title: g.gift, subtitle: "\(store.events.first { $0.id == g.eventID }?.title ?? "Date") · \(g.year)", tint: CareColor.rose)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddDateSheet(person: person) }
        .sheet(item: $giftFor) { event in GiftSheet(person: person, event: event) }
    }
}

struct AddDateSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var title = ""
    @State private var date = Date()
    @State private var yearly = true

    var body: some View {
        SheetScaffold(title: "A date to remember", subtitle: person.shortName, aura: person.aura, primaryTitle: "Add", primaryEnabled: !title.isEmpty) {
            store.addEvent(EventRecord(personID: person.id, moduleID: .dates, category: .milestone, title: title, start: date, isAllDay: true, recurrence: yearly ? .yearly : .none))
        } content: {
            VStack(spacing: CareSpace.sm) {
                CareField("Title", placeholder: "Birthday, anniversary, first date", text: $title)
                CareDateRow("Date", date: $date, components: [.date])
                CareToggleRow("Every year", detail: "Countdown resets after each one", isOn: $yearly)
            }
        }
    }
}

struct GiftSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    let event: EventRecord
    @State private var gift = ""
    @State private var year = Calendar.care.component(.year, from: .now)

    var body: some View {
        SheetScaffold(title: "What did you give?", subtitle: event.title, aura: person.aura, primaryTitle: "Save", primaryEnabled: !gift.isEmpty) {
            store.addEntry(person: person.id, module: .dates, payload: GiftPayload(eventID: event.id, year: year, gift: gift))
        } content: {
            VStack(spacing: CareSpace.sm) {
                CareField("Gift", placeholder: "Dinner at Olive, a book…", text: $gift)
                HStack {
                    Text("Year").font(CareFont.label).foregroundStyle(CareColor.textSecondary)
                    Spacer()
                    Stepper("\(year)", value: $year, in: 2000...2100).font(CareFont.bodyMedium).tint(CareColor.ink)
                }
                .padding(.horizontal, CareSpace.sm).frame(minHeight: 46)
                .background(CareColor.surfaceStrong, in: RoundedRectangle(cornerRadius: CareRadius.inner))
            }
        }
    }
}
