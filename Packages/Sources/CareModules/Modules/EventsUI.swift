import SwiftUI
import CareCore
import CareDesign
import CareData

public enum EventsUI: ModuleUI {
    public static let id: ModuleID = .events

    public static func quickLog(person: PersonRecord, prefill: String?) -> AnyView? {
        // A prefill like "<eventID>|wentWell" answers a follow-up; anything else opens the composer with a title.
        if let prefill, prefill.contains("|") {
            let parts = prefill.split(separator: "|")
            if parts.count == 2, let id = UUID(uuidString: String(parts[0])), let outcome = EventOutcome(rawValue: String(parts[1])) {
                return AnyView(FollowUpSheet(person: person, eventID: id, initialOutcome: outcome))
            }
        }
        return AnyView(EventComposer(person: person, prefillTitle: prefill))
    }

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(EventsDetail(person: person))
    }
}

struct EventsDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showComposer = false
    @State private var followUp: EventRecord?

    var body: some View {
        let ctx = store.context(for: person, module: .events)
        let awaiting = EventsLogic.awaitingFollowUp(ctx)
        let upcoming = EventsLogic.upcoming(ctx, days: 90)
        let past = ctx.events(for: .events).filter { $0.start < ctx.now && !awaiting.contains($0) }.sorted { $0.start > $1.start }
        ModuleScreen(person: person, module: .events, actionTitle: "Add an event", action: { showComposer = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                ForEach(awaiting) { e in
                    VStack(alignment: .leading, spacing: CareSpace.xs) {
                        Text("How did it go?").careType(.labelEmphasis).foregroundStyle(CareColor.upcoming)
                        Text(e.title).careType(.cardTitle).foregroundStyle(CareColor.textPrimary)
                        HStack(spacing: CareSpace.xs) {
                            ForEach(EventOutcome.allCases, id: \.self) { o in
                                PillButton(o.label, style: o == .wentWell ? .ink : .ghost, compact: true) {
                                    store.addEntry(person: person.id, module: .events, payload: EventFollowUpPayload(eventID: e.id, outcome: o))
                                }
                            }
                        }
                    }
                    .careCard(radius: CareRadius.hero, padding: CareSpace.md + 2, attention: false, strong: true)
                }
                CardSection("Coming up", trailing: "\(upcoming.count)") {
                    if upcoming.isEmpty {
                        Text("Nothing ahead. Add what is happening in \(person.shortName)'s life.").careType(.callout).foregroundStyle(CareColor.textSecondary).padding(.horizontal, 4)
                    }
                    ForEach(upcoming) { e in
                        CardRow(symbol: e.category.symbol, title: e.title,
                                subtitle: "\(e.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())) · \(e.category.displayName)\(e.supportNote.map { " · \($0)" } ?? "")",
                                tint: e.category == .health ? CareColor.attention : ModuleAccent.color(for: .events)) {
                            Text(CareDates.relativeDays(from: ctx.now, to: e.start)).careType(.meta).foregroundStyle(CareColor.textMuted)
                        }
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteEvent(e.id) }
                        }
                    }
                }
                if !past.isEmpty {
                    CardSection("Earlier") {
                        ForEach(past.prefix(20)) { e in
                            let outcome = EventsLogic.followUp(for: e, ctx)?.outcome
                            CardRow(symbol: e.category.symbol, title: e.title, subtitle: e.start.formatted(.dateTime.day().month(.abbreviated).year()), tint: CareColor.textMuted, isDone: false) {
                                if let outcome {
                                    Text(outcome.label).careType(.meta).foregroundStyle(outcome == .hard ? CareColor.attention : CareColor.positive)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showComposer) { EventComposer(person: person, prefillTitle: nil) }
    }
}

struct EventComposer: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var title: String
    @State private var category: EventCategory?
    @State private var start = CareDates.at(hour: 10, on: CareDates.adding(days: 1, to: .now))
    @State private var allDay = false
    @State private var note = ""
    @State private var location = ""
    @State private var followUp = true

    init(person: PersonRecord, prefillTitle: String?) {
        self.person = person
        self.title = prefillTitle ?? ""
    }

    var resolvedCategory: EventCategory { category ?? EventCategory.classify(title: title) }

    var body: some View {
        SheetScaffold(title: "Something happening", subtitle: person.shortName, aura: person.aura, primaryTitle: "Add to their timeline", primaryEnabled: !title.isEmpty) {
            store.addEvent(EventRecord(personID: person.id, moduleID: .events, category: resolvedCategory, title: title, start: start,
                                       end: allDay ? nil : CareDates.adding(hours: 1, to: start), isAllDay: allDay, supportNote: note.isEmpty ? nil : note,
                                       location: location.isEmpty ? nil : location, followUp: followUp))
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                CareField("What", placeholder: "Science exam, Dr. Iyer, flight to Goa", text: $title)
                VStack(alignment: .leading, spacing: CareSpace.xs) {
                    SectionLabel("Category", trailing: category == nil ? "guessed from the title" : nil)
                    ChipRow(items: EventCategory.allCases, selection: [resolvedCategory], label: { $0.displayName }) { category = $0 }
                    Text(resolvedCategory.examples).careType(.meta).foregroundStyle(CareColor.textMuted)
                }
                CareDateRow("When", date: $start, components: allDay ? [.date] : [.date, .hourAndMinute])
                CareToggleRow("All day", isOn: $allDay)
                CareField("Where", placeholder: "Optional", text: $location)
                CareField("How to support", placeholder: resolvedCategory.defaults.suggestedAction, text: $note, axis: .vertical)
                CareToggleRow("Ask me how it went", detail: "A nudge after it ends", isOn: $followUp)
                Text("Reminders: \(resolvedCategory.defaults.leadTimeDays.map { "\($0)d before" }.joined(separator: ", ")), and the day of.")
                    .careType(.meta).foregroundStyle(CareColor.textMuted)
            }
        }
    }
}

struct FollowUpSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    let eventID: UUID
    @State private var outcome: EventOutcome
    @State private var note = ""

    init(person: PersonRecord, eventID: UUID, initialOutcome: EventOutcome) {
        self.person = person
        self.eventID = eventID
        self.outcome = initialOutcome
    }

    var body: some View {
        SheetScaffold(title: "How did it go?", subtitle: store.events.first { $0.id == eventID }?.title ?? person.shortName, aura: person.aura, primaryTitle: "Save") {
            store.addEntry(person: person.id, module: .events, payload: EventFollowUpPayload(eventID: eventID, outcome: outcome, note: note.isEmpty ? nil : note))
        } content: {
            VStack(alignment: .leading, spacing: CareSpace.sm) {
                ChipRow(items: EventOutcome.allCases, selection: [outcome], label: { $0.label }) { outcome = $0 }
                CareField("Anything to remember", placeholder: "Optional", text: $note, axis: .vertical)
            }
        }
    }
}
