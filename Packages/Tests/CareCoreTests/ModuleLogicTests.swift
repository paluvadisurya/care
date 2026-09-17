import Testing
import Foundation
@testable import CareCore
import CareFixtures

@Suite("Module logic on the demo circle")
struct ModuleLogicTests {
    let fixture = DemoCircle.make()

    @Test("Dad has a missed evening dose after grace time")
    func missedDose() throws {
        let dad = try #require(fixture.people.first { $0.shortName == "Ramarao" })
        let evening = CareDates.at(hour: 22, minute: 30, on: fixture.now, calendar: fixture.calendar)
        let ctx = ModuleRegistry.standard.context(person: dad, module: .medication, entries: fixture.entries, events: fixture.events, now: evening, calendar: fixture.calendar)
        let signals = MedicationLogic.signals(ctx)
        #expect(signals.contains { $0.kind == .missedDose })
        if case .numeral(let value, _)? = signals.first(where: { $0.kind == .missedDose })?.hero {
            #expect(Int(value) ?? 0 >= 1)
        }
    }

    @Test("Mom's Sunday call carries talking points")
    func callRhythm() throws {
        let mom = try #require(fixture.people.first { $0.shortName == "Kasi" })
        let sunday = fixture.calendar.nextDate(after: fixture.now, matching: DateComponents(hour: 10, weekday: 1), matchingPolicy: .nextTime)!
        let ctx = ModuleRegistry.standard.context(person: mom, module: .callRhythm, entries: fixture.entries, events: fixture.events, now: sunday, calendar: fixture.calendar)
        let signals = CallRhythmLogic.signals(ctx)
        #expect(signals.contains { $0.kind == .callRhythm })
        #expect(!CallRhythmLogic.talkingPoints(ctx).isEmpty)
    }

    @Test("Oreo's food order surfaces before it runs out")
    func petFood() throws {
        let oreo = try #require(fixture.people.first { $0.shortName == "Oreo" })
        let ctx = ModuleRegistry.standard.context(person: oreo, module: .petCare, entries: fixture.entries, events: fixture.events, now: fixture.now, calendar: fixture.calendar)
        let dues = PetCareLogic.dues(ctx)
        #expect(dues.contains { $0.kind == .foodOrder })
    }

    @Test("Every implemented module returns a today state without crashing")
    func todayStates() {
        for person in fixture.people {
            for module in person.enabledModules {
                guard let logic = ModuleRegistry.standard.logic(for: module) else { continue }
                let ctx = ModuleRegistry.standard.context(person: person, module: module, entries: fixture.entries, events: fixture.events, now: fixture.now, calendar: fixture.calendar)
                let state = logic.todayState(ctx)
                #expect(!state.headline.isEmpty)
            }
        }
    }

    @Test("The circle produces ranked signals with a hero")
    func heroExists() {
        let signals = ModuleRegistry.standard.signals(people: fixture.people, entries: fixture.entries, events: fixture.events, now: fixture.now)
        #expect(!signals.isEmpty)
        #expect(HomeRanker.hero(from: HomeRanker.rank(signals, now: fixture.now)) != nil)
    }

    @Test("Wedding anniversary is a future yearly date for Srivalli")
    func anniversary() throws {
        let srivalli = try #require(fixture.people.first { $0.shortName == "Srivalli" })
        let ctx = ModuleRegistry.standard.context(person: srivalli, module: .dates, entries: fixture.entries, events: fixture.events, now: fixture.now, calendar: fixture.calendar)
        let up = DatesLogic.upcoming(ctx)
        #expect(up.contains { $0.event.title.contains("anniversary") })
    }
}
