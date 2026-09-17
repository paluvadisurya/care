import Testing
import Foundation
@testable import CareReminders
import CareCore
import CareFixtures

@Suite("Reminder guardrails")
struct GuardrailsTests {
    let fixture = DemoCircle.make()

    @Test("Nothing fires inside quiet hours except medication")
    func quietHours() {
        let planner = ReminderPlanner(calendar: fixture.calendar)
        let planned = planner.plan(people: fixture.people, entries: fixture.entries, events: fixture.events, prefs: .default, now: fixture.now)
        for r in planned where r.kind != .medication {
            #expect(!CareDates.isQuiet(r.fireAt, quietHours: ["22:00", "07:00"], calendar: fixture.calendar))
        }
    }

    @Test("The daily cap holds")
    func cap() {
        let planner = ReminderPlanner(calendar: fixture.calendar)
        let prefs = ReminderPreferences(dailyCap: 2)
        let planned = planner.plan(people: fixture.people, entries: fixture.entries, events: fixture.events, prefs: prefs, now: fixture.now)
        let counted = planned.filter { $0.kind != .medication && $0.kind != .morningBrief && $0.kind != .eveningWrap }
        #expect(counted.count <= 2)
    }

    @Test("Muted kinds never fire")
    func muted() {
        let planner = ReminderPlanner(calendar: fixture.calendar)
        let prefs = ReminderPreferences(mutedKinds: [.hydration, .pulseCheck])
        let planned = planner.plan(people: fixture.people, entries: fixture.entries, events: fixture.events, prefs: prefs, now: fixture.now)
        #expect(!planned.contains { $0.kind == .hydration || $0.kind == .pulseCheck })
    }

    @Test("Every reminder names a person and a reason")
    func reasons() {
        let planner = ReminderPlanner(calendar: fixture.calendar)
        let planned = planner.plan(people: fixture.people, entries: fixture.entries, events: fixture.events, prefs: .default, now: fixture.now)
        for r in planned {
            #expect(!r.personName.isEmpty)
            #expect(!r.reason.isEmpty)
        }
    }
}
