import Foundation
import CareCore

/// Rules first, guardrails last. The model step ("words second") is optional and only rewrites messages.
public struct ReminderPlanner: Sendable {
    public var registry: ModuleRegistry
    public var calendar: Calendar

    public init(registry: ModuleRegistry = .standard, calendar: Calendar = .care) {
        self.registry = registry
        self.calendar = calendar
    }

    public func plan(people: [PersonRecord], entries: [EntryRecord], events: [EventRecord], prefs: ReminderPreferences, now: Date) -> [PlannedReminder] {
        let candidates = registry.reminderCandidates(people: people, entries: entries, events: events, now: now)
        let away = Set(people.filter { person in
            guard person.isEnabled(.travelPlans) else { return false }
            let ctx = registry.context(person: person, module: .travelPlans, entries: entries, events: events, now: now, calendar: calendar)
            return TravelPlansLogic.isAway(ctx) != nil
        }.map(\.id))
        var planned = Guardrails.apply(candidates, people: people, prefs: prefs, now: now, calendar: calendar, awayPeople: away)
        if let me = people.first(where: { $0.relationship == .me }) {
            planned += Guardrails.standing(prefs: prefs, now: now, calendar: calendar, peopleCount: people.count, meID: me.id)
        }
        return planned.sorted { $0.fireAt < $1.fireAt }
    }
}
