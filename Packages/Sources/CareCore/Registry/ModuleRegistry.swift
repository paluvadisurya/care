import Foundation

/// All module logic the app knows about. Adding a module means appending one line to `standard`.
public struct ModuleRegistry: Sendable {
    public let modules: [any ModuleLogic.Type]

    public init(modules: [any ModuleLogic.Type]) {
        self.modules = modules
    }

    public static let standard = ModuleRegistry(modules: [
        MoodLogic.self,
        HealthLogic.self,
        HydrationLogic.self,
        MentionsLogic.self,
        DatesLogic.self,
        EventsLogic.self,
        MedicationLogic.self,
        AppointmentsLogic.self,
        CallRhythmLogic.self,
        TravelPlansLogic.self,
        SharedChecklistLogic.self,
        PromisesLogic.self,
        WishlistLogic.self,
        PetCareLogic.self,
    ])

    public func logic(for id: ModuleID) -> (any ModuleLogic.Type)? {
        modules.first { $0.meta.id == id }
    }

    public var implementedIDs: [ModuleID] { modules.map { $0.meta.id } }

    public func isImplemented(_ id: ModuleID) -> Bool { logic(for: id) != nil }

    /// Build a context for one person and module from the full record set.
    public func context(person: PersonRecord, module: ModuleID, entries: [EntryRecord], events: [EventRecord],
                        now: Date, calendar: Calendar = .care) -> ModuleContext {
        let mine = entries.filter { $0.personID == person.id }
        return ModuleContext(
            person: person,
            entries: mine.filter { $0.moduleID == module }.sorted { $0.occurredAt > $1.occurredAt },
            events: events.filter { $0.personID == person.id },
            allEntries: mine,
            now: now,
            calendar: calendar
        )
    }

    /// Signals for everyone, unranked.
    public func signals(people: [PersonRecord], entries: [EntryRecord], events: [EventRecord], now: Date,
                        entitlement: EntitlementService = .shared) -> [Signal] {
        var out: [Signal] = []
        for person in people {
            for module in person.enabledModules where entitlement.isUnlocked(module) {
                guard let logic = logic(for: module) else { continue }
                let ctx = context(person: person, module: module, entries: entries, events: events, now: now)
                out += logic.signals(ctx)
            }
        }
        return out
    }

    public func timelineItems(people: [PersonRecord], entries: [EntryRecord], events: [EventRecord], day: Date,
                              now: Date) -> [TimelineItem] {
        var out: [TimelineItem] = []
        for person in people {
            for module in person.enabledModules {
                guard let logic = logic(for: module) else { continue }
                let ctx = context(person: person, module: module, entries: entries, events: events, now: now)
                out += logic.timelineItems(ctx, day: day)
            }
        }
        return out.sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.start < b.start
        }
    }

    public func packs(person: PersonRecord, entries: [EntryRecord], events: [EventRecord], window: DateInterval,
                      now: Date) -> [ContextPack] {
        person.enabledModules.compactMap { module in
            guard let logic = logic(for: module) else { return nil }
            let ctx = context(person: person, module: module, entries: entries, events: events, now: now)
            return logic.contextPack(ctx, window: window)
        }
    }

    public func reminderCandidates(people: [PersonRecord], entries: [EntryRecord], events: [EventRecord],
                                   now: Date) -> [ReminderCandidate] {
        var out: [ReminderCandidate] = []
        for person in people {
            for module in person.enabledModules {
                guard let logic = logic(for: module) else { continue }
                let ctx = context(person: person, module: module, entries: entries, events: events, now: now)
                out += logic.reminderCandidates(ctx)
            }
        }
        return out
    }
}
