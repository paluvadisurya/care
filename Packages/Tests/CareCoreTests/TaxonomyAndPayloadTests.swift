import Testing
import Foundation
@testable import CareCore

@Suite("Event taxonomy")
struct TaxonomyTests {
    @Test("Health events get a one-day lead and a same-evening follow-up")
    func healthDefaults() {
        let d = EventCategory.health.defaults
        #expect(d.leadTimeDays == [1])
        #expect(d.followUp == .sameEvening)
    }

    @Test("Milestones get 14 and 3 day leads and no follow-up")
    func milestoneDefaults() {
        let d = EventCategory.milestone.defaults
        #expect(d.leadTimeDays == [14, 3])
        #expect(d.followUp == nil)
    }

    @Test("Titles classify on device", arguments: [
        ("Dr. Iyer, cardiology", EventCategory.health),
        ("Science exam", .workAndSchool),
        ("Flight to Goa", .travel),
        ("Diwali", .faithAndCulture),
        ("Anniversary dinner", .milestone),
        ("10k race", .personal),
    ])
    func classify(title: String, expected: EventCategory) {
        #expect(EventCategory.classify(title: title) == expected)
    }

    @Test("An event created without lead times inherits the category defaults")
    func inheritedDefaults() {
        let e = EventRecord(personID: UUID(), category: .travel, title: "Goa", start: .now)
        #expect(e.leadTimes == [7, 1])
        #expect(e.followUp)
    }

    @Test("Yearly dates roll to the next occurrence")
    func yearlyRoll() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let wedding = cal.date(from: DateComponents(year: 2026, month: 8, day: 26))!
        let e = EventRecord(personID: UUID(), moduleID: .dates, category: .milestone, title: "Wedding anniversary", start: wedding, recurrence: .yearly)
        let today = cal.date(from: DateComponents(year: 2026, month: 9, day: 17))!
        let next = e.nextOccurrence(after: today, calendar: cal)
        #expect(cal.component(.year, from: next) == 2027)
        #expect(e.yearsAt(today, calendar: cal) == 1)
    }
}

@Suite("Payloads")
struct PayloadTests {
    @Test("Every payload round-trips through the shared coder")
    func roundTrip() throws {
        let mood = MoodPayload(value: 4, energy: 3, tag: "work")
        let data = try PayloadCoder.encode(mood)
        #expect(try PayloadCoder.decode(MoodPayload.self, from: data) == mood)

        let med = MedicationSettings(medicines: [Medicine(name: "Telmisartan", dose: "40 mg", times: [TimeOfDay(hour: 8), TimeOfDay(hour: 20)], refillDate: .now)])
        let medData = try PayloadCoder.encode(med)
        #expect(try PayloadCoder.decode(MedicationSettings.self, from: medData).medicines.first?.times.count == 2)

        let trip = TripPayload(destination: "Goa", from: .now, to: .now.addingTimeInterval(86400 * 3), packing: [PackingItem(text: "Charger")])
        let tripData = try PayloadCoder.encode(trip)
        #expect(try PayloadCoder.decode(TripPayload.self, from: tripData).destination == "Goa")
    }

    @Test("Input hash is stable across encodes")
    func stableHash() {
        let a = PayloadCoder.inputHash(["b": 1, "a": 2])
        let b = PayloadCoder.inputHash(["a": 2, "b": 1])
        #expect(a == b)
    }

    @Test("Mention classifier finds wants and worries")
    func mentionClassifier() {
        #expect(MentionClassifier.classify("She wants to try the pottery class") == .want)
        #expect(MentionClassifier.classify("Worried about the presentation on Friday") == .worry)
        #expect(MentionClassifier.classify("Hates cilantro") == .dislike)
        #expect(MentionClassifier.classify("Sister visits next week") == .fact)
    }
}

@Suite("Deep links")
struct DeepLinkTests {
    @Test("Links round-trip through URLs")
    func roundTrip() {
        let id = UUID()
        let links: [DeepLink] = [.today, .you, .person(id), .module(personID: id, module: .mood),
                                 .newEntry(personID: id, module: .events, title: "Dinner"), .quickSheet(personID: id), .timeline(day: "2026-09-17")]
        for link in links {
            #expect(DeepLink(url: link.url) == link)
        }
    }

    @Test("Unknown module fails to parse")
    func unknownModule() {
        #expect(DeepLink(string: "care://person/\(UUID().uuidString)/nonsense") == nil)
    }
}
