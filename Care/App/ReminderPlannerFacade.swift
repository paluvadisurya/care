import Foundation
import CareCore
import CareData
import CareReminders

/// Thin bridge so the app target never imports planner internals in more than one place.
enum ReminderPlannerFacade {
    static func plan(store: CareStore, prefs: AppPreferences, now: Date = .now) -> [PlannedReminder] {
        ReminderPlanner(registry: store.registry, calendar: store.calendar)
            .plan(people: store.people, entries: store.entries, events: store.events, prefs: prefs.reminders, now: now)
    }
}
