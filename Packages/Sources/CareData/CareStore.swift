import Foundation
import Observation
import SwiftData
import CareCore
import CareIntelligence
import CareFixtures

/// The app's single source of truth for records. Loads everything into memory (Phase 0 is one household),
/// writes through to SwiftData, and exposes pure-Swift records to views and engines.
@Observable
public final class CareStore {
    public private(set) var people: [PersonRecord] = []
    public private(set) var entries: [EntryRecord] = []
    public private(set) var events: [EventRecord] = []
    public private(set) var insights: [InsightRecord] = []
    public private(set) var isLoaded = false

    public let registry: ModuleRegistry
    public var calendar: Calendar
    private let context: ModelContext

    public init(container: ModelContainer, registry: ModuleRegistry = .standard, calendar: Calendar = .care) {
        self.context = ModelContext(container)
        self.context.autosaveEnabled = true
        self.registry = registry
        self.calendar = calendar
    }

    // MARK: Loading

    public func load() {
        let personModels = (try? context.fetch(FetchDescriptor<PersonModel>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        people = personModels.map(\.record).sorted { $0.sortOrder < $1.sortOrder }
        let entryModels = (try? context.fetch(FetchDescriptor<EntryModel>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        entries = entryModels.compactMap(\.record).sorted { $0.occurredAt > $1.occurredAt }
        let eventModels = (try? context.fetch(FetchDescriptor<EventModel>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        events = eventModels.map(\.record).sorted { $0.start < $1.start }
        let insightModels = (try? context.fetch(FetchDescriptor<InsightModel>())) ?? []
        insights = insightModels.compactMap(\.record)
        isLoaded = true
    }

    public var isEmpty: Bool { people.isEmpty }

    /// Seeds the demo circle relative to today. Used by onboarding's "Try the demo" and by screenshots.
    public func seedDemo(now: Date = .now) {
        let demo = DemoCircle.make(now: now, calendar: calendar)
        for p in demo.people { context.insert(PersonModel(record: p)) }
        for e in demo.entries { context.insert(EntryModel(record: e)) }
        for e in demo.events { context.insert(EventModel(record: e)) }
        save()
        load()
    }

    public func wipeEverything() {
        for m in (try? context.fetch(FetchDescriptor<PersonModel>())) ?? [] { context.delete(m) }
        for m in (try? context.fetch(FetchDescriptor<EntryModel>())) ?? [] { context.delete(m) }
        for m in (try? context.fetch(FetchDescriptor<EventModel>())) ?? [] { context.delete(m) }
        for m in (try? context.fetch(FetchDescriptor<InsightModel>())) ?? [] { context.delete(m) }
        save()
        load()
    }

    private func save() {
        do { try context.save() } catch { assertionFailure("Save failed: \(error)") }
    }

    // MARK: People

    public var me: PersonRecord? { people.first { $0.relationship == .me } }
    public var others: [PersonRecord] { people.filter { $0.relationship != .me } }

    public func person(_ id: UUID) -> PersonRecord? { people.first { $0.id == id } }

    public func addPerson(_ record: PersonRecord) {
        var r = record
        r.sortOrder = (people.map(\.sortOrder).max() ?? -1) + 1
        context.insert(PersonModel(record: r))
        save()
        people.append(r)
        people.sort { $0.sortOrder < $1.sortOrder }
    }

    public func updatePerson(_ record: PersonRecord) {
        guard let model = fetchPerson(record.id) else { return }
        model.apply(record)
        save()
        if let i = people.firstIndex(where: { $0.id == record.id }) {
            var r = record
            r.updatedAt = model.updatedAt
            people[i] = r
        }
    }

    public func deletePerson(_ id: UUID) {
        guard let model = fetchPerson(id) else { return }
        model.deletedAt = .now
        for e in (try? context.fetch(FetchDescriptor<EntryModel>(predicate: #Predicate { $0.personID == id }))) ?? [] { e.deletedAt = .now }
        for e in (try? context.fetch(FetchDescriptor<EventModel>(predicate: #Predicate { $0.personID == id }))) ?? [] { e.deletedAt = .now }
        save()
        people.removeAll { $0.id == id }
        entries.removeAll { $0.personID == id }
        events.removeAll { $0.personID == id }
    }

    public func setModule(_ module: ModuleID, enabled: Bool, for personID: UUID) {
        guard var p = person(personID) else { return }
        if enabled { if !p.enabledModules.contains(module) { p.enabledModules.append(module) } }
        else { p.enabledModules.removeAll { $0 == module } }
        updatePerson(p)
    }

    public func movePeople(fromOffsets: IndexSet, toOffset: Int) {
        var list = people
        let moving = fromOffsets.sorted().map { list[$0] }
        let before = fromOffsets.filter { $0 < toOffset }.count
        for i in fromOffsets.sorted(by: >) { list.remove(at: i) }
        list.insert(contentsOf: moving, at: max(0, min(list.count, toOffset - before)))
        for (i, var p) in list.enumerated() where p.sortOrder != i {
            p.sortOrder = i
            updatePerson(p)
        }
        people = list
    }

    private func fetchPerson(_ id: UUID) -> PersonModel? {
        try? context.fetch(FetchDescriptor<PersonModel>(predicate: #Predicate { $0.id == id })).first
    }

    // MARK: Entries

    public func entries(for personID: UUID, module: ModuleID? = nil) -> [EntryRecord] {
        entries.filter { $0.personID == personID && (module == nil || $0.moduleID == module) }
    }

    @discardableResult
    public func addEntry<T: Encodable>(person personID: UUID, module: ModuleID, at: Date = .now, author: Author? = nil,
                                       source: EntrySource = .manual, tags: [String] = [], payload: T) -> EntryRecord? {
        guard let data = try? PayloadCoder.encode(payload) else { return nil }
        let isMe = person(personID)?.relationship == .me
        let record = EntryRecord(personID: personID, moduleID: module, occurredAt: at, author: author ?? (isMe ? .selfReport : .observed),
                                 source: source, payload: data, tags: tags)
        context.insert(EntryModel(record: record))
        save()
        entries.insert(record, at: 0)
        entries.sort { $0.occurredAt > $1.occurredAt }
        return record
    }

    public func updateEntry<T: Encodable>(_ id: UUID, payload: T, at: Date? = nil) {
        guard let model = try? context.fetch(FetchDescriptor<EntryModel>(predicate: #Predicate { $0.id == id })).first,
              var record = model.record, let data = try? PayloadCoder.encode(payload) else { return }
        record.payload = data
        if let at { record.occurredAt = at }
        model.apply(record)
        save()
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i] = record }
    }

    public func deleteEntry(_ id: UUID) {
        guard let model = try? context.fetch(FetchDescriptor<EntryModel>(predicate: #Predicate { $0.id == id })).first else { return }
        model.deletedAt = .now
        save()
        entries.removeAll { $0.id == id }
    }

    // MARK: Events

    public func events(for personID: UUID, module: ModuleID? = nil) -> [EventRecord] {
        events.filter { $0.personID == personID && (module == nil || $0.moduleID == module) }
    }

    public func addEvent(_ record: EventRecord) {
        context.insert(EventModel(record: record))
        save()
        events.append(record)
        events.sort { $0.start < $1.start }
    }

    public func updateEvent(_ record: EventRecord) {
        let id = record.id
        guard let model = try? context.fetch(FetchDescriptor<EventModel>(predicate: #Predicate { $0.id == id })).first else { return }
        model.apply(record)
        save()
        if let i = events.firstIndex(where: { $0.id == id }) { events[i] = record }
        events.sort { $0.start < $1.start }
    }

    public func deleteEvent(_ id: UUID) {
        guard let model = try? context.fetch(FetchDescriptor<EventModel>(predicate: #Predicate { $0.id == id })).first else { return }
        model.deletedAt = .now
        save()
        events.removeAll { $0.id == id }
    }

    // MARK: Insights

    public func insight(scope: ScopeContext.Scope, scopeID: UUID?) -> InsightRecord? {
        insights.first { $0.scope == scope && $0.scopeID == scopeID }
    }

    public func saveInsight(_ record: InsightRecord) {
        if let existing = insights.first(where: { $0.scope == record.scope && $0.scopeID == record.scopeID }) {
            let id = existing.id
            if let model = try? context.fetch(FetchDescriptor<InsightModel>(predicate: #Predicate { $0.id == id })).first {
                var r = record
                r.id = id
                model.apply(r)
                save()
                if let i = insights.firstIndex(where: { $0.id == id }) { insights[i] = r }
                return
            }
        }
        context.insert(InsightModel(record: record))
        save()
        insights.append(record)
    }

    public func setFeedback(_ feedback: InsightFeedback?, for insightID: UUID) {
        guard var r = insights.first(where: { $0.id == insightID }) else { return }
        r.feedback = feedback
        saveInsight(r)
    }

    // MARK: Derived

    public func context(for person: PersonRecord, module: ModuleID, now: Date = .now) -> ModuleContext {
        registry.context(person: person, module: module, entries: entries, events: events, now: now, calendar: calendar)
    }

    public func todayState(for person: PersonRecord, module: ModuleID, now: Date = .now) -> ModuleTodayState {
        guard let logic = registry.logic(for: module) else { return .empty }
        return logic.todayState(context(for: person, module: module, now: now))
    }

    public func signals(now: Date = .now) -> [Signal] {
        HomeRanker.rank(registry.signals(people: people, entries: entries, events: events, now: now), now: now)
    }

    public func signals(for personID: UUID, now: Date = .now) -> [Signal] {
        signals(now: now).filter { $0.personID == personID }
    }

    public func timelineItems(day: Date, now: Date = .now) -> [TimelineItem] {
        registry.timelineItems(people: people, entries: entries, events: events, day: day, now: now)
    }

    /// One line of status for the aura header, from the person's most telling module.
    public func statusLine(for person: PersonRecord, now: Date = .now) -> String {
        let ranked = signals(for: person.id, now: now)
        if let top = ranked.first { return top.body }
        if person.isEnabled(.mood), let last = entries(for: person.id, module: .mood).first, let m = last.decode(MoodPayload.self) {
            return "\(ModuleHelpers.moodWord(m.value)). Checked in \(CareDates.relativeShort(from: now, to: last.occurredAt))."
        }
        if person.relationship == .pet { return "All good. Nothing due this week." }
        return "Nothing needs you today."
    }

    /// Export everything as one JSON document. Lives in Files; nothing leaves the device unless the user shares it.
    public func exportJSON() -> Data {
        struct Export: Encodable {
            var exportedAt: Date
            var people: [PersonRecord]
            var entries: [EntryRecord]
            var events: [EventRecord]
        }
        let e = Export(exportedAt: .now, people: people, entries: entries, events: events)
        return (try? PayloadCoder.encoder.encode(e)) ?? Data()
    }
}
