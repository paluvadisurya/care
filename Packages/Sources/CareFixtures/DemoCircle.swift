import Foundation
import CareCore

/// The demo profile: one real-shaped family, frozen at a moment so previews, tests and screenshots agree.
/// Names come from the founder's circle. Birthdays and cities are placeholders to edit in the app.
public struct DemoCircle: Sendable {
    public var userName: String
    public var people: [PersonRecord]
    public var entries: [EntryRecord]
    public var events: [EventRecord]
    public var now: Date
    public var calendar: Calendar

    // Stable ids so deep links in previews never change.
    public static let suryaID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!
    public static let srivalliID = UUID(uuidString: "A0000000-0000-4000-8000-000000000002")!
    public static let ramaraoID = UUID(uuidString: "A0000000-0000-4000-8000-000000000003")!
    public static let annapurnaID = UUID(uuidString: "A0000000-0000-4000-8000-000000000004")!
    public static let neerajID = UUID(uuidString: "A0000000-0000-4000-8000-000000000005")!
    public static let oreoID = UUID(uuidString: "A0000000-0000-4000-8000-000000000006")!

    public static let telmisartanID = UUID(uuidString: "B0000000-0000-4000-8000-000000000001")!
    public static let amlodipineDadID = UUID(uuidString: "B0000000-0000-4000-8000-000000000002")!
    public static let metforminID = UUID(uuidString: "B0000000-0000-4000-8000-000000000003")!
    public static let amlodipineMomID = UUID(uuidString: "B0000000-0000-4000-8000-000000000004")!
    public static let anniversaryID = UUID(uuidString: "C0000000-0000-4000-8000-000000000001")!

    /// Thursday 17 September 2026, 09:41 in Hyderabad.
    public static func demoNow(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 9, minute: 41))!
    }

    public static func demoCalendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        c.locale = Locale(identifier: "en_IN")
        return c
    }

    /// Builds the circle. Pass `now: .now` to seed a live database relative to today.
    public static func make(now: Date? = nil, calendar: Calendar = demoCalendar()) -> DemoCircle {
        let now = now ?? demoNow(calendar: calendar)
        var b = Builder(now: now, calendar: calendar)
        b.build()
        return DemoCircle(userName: "Surya", people: b.people, entries: b.entries, events: b.events, now: now, calendar: calendar)
    }

    struct Builder {
        let now: Date
        let calendar: Calendar
        var people: [PersonRecord] = []
        var entries: [EntryRecord] = []
        var events: [EventRecord] = []

        init(now: Date, calendar: Calendar) {
            self.now = now
            self.calendar = calendar
        }

        func day(_ daysAgo: Int, hour: Int = 9, minute: Int = 0) -> Date {
            CareDates.at(hour: hour, minute: minute, on: CareDates.adding(days: -daysAgo, to: now, calendar: calendar), calendar: calendar)
        }

        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? now
        }

        mutating func add<T: Encodable>(_ person: UUID, _ module: ModuleID, at: Date, author: Author = .observed, source: EntrySource = .seed, tags: [String] = [], _ payload: T) {
            guard let data = try? PayloadCoder.encode(payload) else { return }
            entries.append(EntryRecord(personID: person, moduleID: module, occurredAt: at, author: author, source: source, payload: data, tags: tags, createdAt: at, updatedAt: at))
        }

        mutating func event(_ person: UUID, _ module: ModuleID = .events, _ category: EventCategory, _ title: String, start: Date, end: Date? = nil,
                            allDay: Bool = false, yearly: Bool = false, note: String? = nil, location: String? = nil, id: UUID = UUID(), payload: (any Encodable)? = nil) {
            let data = payload.flatMap { try? PayloadCoder.encode(AnyEncodable($0)) }
            events.append(EventRecord(id: id, personID: person, moduleID: module, category: category, title: title, start: start, end: end, isAllDay: allDay,
                                      recurrence: yearly ? .yearly : .none, supportNote: note, location: location, source: .seed, payload: data))
        }

        mutating func build() {
            buildSurya()
            buildSrivalli()
            buildRamarao()
            buildAnnapurna()
            buildNeeraj()
            buildOreo()
        }

        // MARK: Surya (me)

        mutating func buildSurya() {
            var me = PersonRecord(id: DemoCircle.suryaID, name: "Paluvadi Surya", shortName: "Surya", relationship: .me, aura: .ink,
                                  birthday: date(1996, 3, 14), homeCity: "Hyderabad", timeZoneIdentifier: "Asia/Kolkata", sortOrder: 0,
                                  enabledModules: [.mood, .health, .hydration, .dates, .travelPlans, .promises])
            me.setSettings(HydrationSettings(targetML: 3000, cupML: 250), for: .hydration)
            people.append(me)

            for (i, v) in [4, 4, 3, 4, 5, 4, 3, 4, 4, 2, 4, 5, 4, 4].enumerated() {
                add(me.id, .mood, at: day(13 - i, hour: 21), author: .selfReport, MoodPayload(value: v, energy: min(5, v + 1), tag: v <= 2 ? "work" : nil))
            }
            add(me.id, .hydration, at: day(0, hour: 7, minute: 30), author: .selfReport, HydrationPayload(milliliters: 250))
            add(me.id, .hydration, at: day(0, hour: 9, minute: 10), author: .selfReport, HydrationPayload(milliliters: 250))
            for d in 1...7 {
                for h in [8, 11, 14, 17, 20] where !(d == 3 && h > 14) {
                    add(me.id, .hydration, at: day(d, hour: h), author: .selfReport, HydrationPayload(milliliters: h == 14 ? 750 : 500))
                }
            }
            add(me.id, .health, at: day(1, hour: 22), author: .selfReport, HealthPayload(state: .allGood))
            add(me.id, .travelPlans, at: date(2026, 10, 3), author: .selfReport, TripPayload(
                destination: "Coorg", from: date(2026, 10, 3, 6), to: date(2026, 10, 6, 21), travelers: ["Surya", "Srivalli"],
                packing: [PackingItem(text: "Rain jackets", done: true), PackingItem(text: "Camera", done: true), PackingItem(text: "Chargers", done: true),
                          PackingItem(text: "Trek shoes", done: true), PackingItem(text: "Homestay booking"), PackingItem(text: "Coffee estate tour"),
                          PackingItem(text: "Oreo's boarding"), PackingItem(text: "Dad's medicine list for Mom"), PackingItem(text: "Power bank")],
                notes: "First trip since the wedding."))
            add(me.id, .promises, at: day(6), author: .selfReport, PromisePayload(text: "Fix the balcony light", due: day(-2)))
            event(me.id, .dates, .milestone, "Surya's birthday", start: date(1996, 3, 14), allDay: true, yearly: true)
        }

        // MARK: Srivalli (partner, married 26 August 2026)

        mutating func buildSrivalli() {
            let p = PersonRecord(id: DemoCircle.srivalliID, name: "Srivalli", relationship: .partner, aura: .coralRose,
                                 birthday: date(1998, 11, 12), homeCity: "Hyderabad", timeZoneIdentifier: "Asia/Kolkata",
                                 note: "Married 26 August 2026", sortOrder: 1,
                                 enabledModules: [.mood, .health, .mentions, .dates, .events, .sharedChecklist, .travelPlans, .wishlist, .promises])
            people.append(p)

            // Mood: a good month with Wednesday dips (observed by Surya).
            let moods = [4, 4, 2, 4, 5, 4, 4, 3, 4, 2, 4, 5, 4, 4, 4, 3, 2, 4, 4, 5, 4, 4, 4, 2, 4, 4, 5, 4, 4, 4]
            for (i, v) in moods.enumerated() {
                let at = day(29 - i, hour: 21, minute: 15)
                let isWed = calendar.component(.weekday, from: at) == 4
                add(p.id, .mood, at: at, MoodPayload(value: isWed ? min(v, 2) : v, tag: isWed ? "work" : nil))
            }
            add(p.id, .health, at: day(1, hour: 20), HealthPayload(state: .neutral, symptoms: ["back pain"], note: "After the long drive"))
            add(p.id, .health, at: day(0, hour: 8), HealthPayload(state: .neutral, symptoms: ["back pain"]))

            add(p.id, .mentions, at: day(15, hour: 19), MentionPayload(text: "Wants to try the pottery class in Jubilee Hills", kind: .want))
            add(p.id, .mentions, at: day(9, hour: 20), MentionPayload(text: "Pottery class again. She has looked it up twice", kind: .want))
            add(p.id, .mentions, at: day(6, hour: 13), MentionPayload(text: "Loves jasmine, hates coriander in anything", kind: .like))
            add(p.id, .mentions, at: day(4, hour: 22), MentionPayload(text: "Worried about the Friday presentation to the new VP", kind: .worry))
            add(p.id, .mentions, at: day(2, hour: 18), MentionPayload(text: "Wants a weekend in the hills before winter", kind: .want))
            add(p.id, .mentions, at: day(12, hour: 11), MentionPayload(text: "Her mother's knee surgery went well", kind: .fact, resolved: true))

            event(p.id, .events, .workAndSchool, "Presentation to the new VP", start: day(-2, hour: 15), end: day(-2, hour: 16), note: "Send a good-luck text at 8am. Light dinner after.")
            event(p.id, .events, .social, "Dinner, just us", start: day(0, hour: 19, minute: 30), end: day(0, hour: 21, minute: 30), location: "Olive Bistro")
            event(p.id, .events, .social, "Cousin's engagement", start: date(2026, 9, 27, 18), end: date(2026, 9, 27, 22), location: "Vijayawada")
            event(p.id, .dates, .milestone, "Wedding anniversary", start: date(2026, 8, 26), allDay: true, yearly: true, id: DemoCircle.anniversaryID)
            event(p.id, .dates, .milestone, "Srivalli's birthday", start: date(1998, 11, 12), allDay: true, yearly: true)
            event(p.id, .dates, .milestone, "First date", start: date(2024, 10, 5), allDay: true, yearly: true)

            add(p.id, .sharedChecklist, at: day(11), ChecklistItemPayload(text: "Curtains for the new flat", dueDate: day(-3)))
            add(p.id, .sharedChecklist, at: day(16), ChecklistItemPayload(text: "Book the dentist", dueDate: day(0)))
            add(p.id, .sharedChecklist, at: day(3), ChecklistItemPayload(text: "Gift for Neeraj's birthday"))
            add(p.id, .sharedChecklist, at: day(20), ChecklistItemPayload(text: "Change the address on Aadhaar", done: true, doneAt: day(8), doneBy: "Srivalli"))
            add(p.id, .sharedChecklist, at: day(18), ChecklistItemPayload(text: "Return the mixer", done: true, doneAt: day(10), doneBy: "Surya"))
            add(p.id, .sharedChecklist, at: day(25), ChecklistItemPayload(text: "Wedding album pickup", done: true, doneAt: day(5), doneBy: "Srivalli"))

            add(p.id, .travelPlans, at: date(2026, 10, 3), TripPayload(destination: "Coorg", from: date(2026, 10, 3, 6), to: date(2026, 10, 6, 21), travelers: ["Surya", "Srivalli"],
                                                                  packing: [PackingItem(text: "Rain jacket", done: true), PackingItem(text: "Hiking shoes", done: true), PackingItem(text: "Book for the drive"), PackingItem(text: "Estate tour tickets")]))

            add(p.id, .wishlist, at: day(21), WishlistItemPayload(title: "Pottery starter kit", url: "https://example.com/pottery-kit", price: 2499, note: "She mentioned it twice"))
            add(p.id, .wishlist, at: day(14), WishlistItemPayload(title: "Jasmine perfume, Forest Essentials", price: 3200))
            add(p.id, .wishlist, at: day(10), WishlistItemPayload(title: "Kindle Paperwhite", price: 14999))
            add(p.id, .wishlist, at: day(7), WishlistItemPayload(title: "Linen kurta set, size M", price: 2800, note: "Sage or rust"))
            add(p.id, .wishlist, at: day(5), WishlistItemPayload(title: "Coorg homestay weekend", price: 9000))
            add(p.id, .wishlist, at: day(30), WishlistItemPayload(title: "Anything with coriander", doNotBuy: true))

            add(p.id, .promises, at: day(8), PromisePayload(text: "Book the pottery class for a Saturday", due: day(-3)))
            add(p.id, .promises, at: day(20), PromisePayload(text: "Frame the wedding photo", kept: true, keptAt: day(4)))
        }

        // MARK: Ramarao (father, BP and pre-diabetic)

        mutating func buildRamarao() {
            var p = PersonRecord(id: DemoCircle.ramaraoID, name: "Ramarao", relationship: .parent, aura: .skyViolet,
                                 birthday: date(1965, 1, 10), homeCity: "Vijayawada", timeZoneIdentifier: "Asia/Kolkata",
                                 note: "BP patient, pre-diabetic. Mom gives the evening tablets.", sortOrder: 2,
                                 enabledModules: [.health, .medication, .appointments, .dates, .mentions, .callRhythm])
            p.setSettings(MedicationSettings(medicines: [
                Medicine(id: DemoCircle.telmisartanID, name: "Telmisartan", dose: "40 mg", times: [TimeOfDay(hour: 8)], purpose: "Blood pressure", refillDate: date(2026, 10, 9), givenBy: nil),
                Medicine(id: DemoCircle.amlodipineDadID, name: "Amlodipine", dose: "5 mg", times: [TimeOfDay(hour: 20)], purpose: "Blood pressure", refillDate: date(2026, 9, 21), givenBy: "Mom"),
                Medicine(id: DemoCircle.metforminID, name: "Metformin", dose: "500 mg", times: [TimeOfDay(hour: 20, minute: 30)], withFood: true, purpose: "Blood sugar", refillDate: date(2026, 10, 2), givenBy: "Mom"),
            ]), for: .medication)
            p.setSettings(CallRhythmSettings(weekday: 4, hour: 19), for: .callRhythm)   // Wednesdays
            people.append(p)

            // Doses for the last 14 days: mostly taken, Wednesdays slip.
            for d in 1...14 {
                let dayDate = CareDates.adding(days: -d, to: now, calendar: calendar)
                let isWed = calendar.component(.weekday, from: dayDate) == 4
                add(p.id, .medication, at: day(d, hour: 8, minute: 5), DosePayload(medicineID: DemoCircle.telmisartanID, scheduledAt: day(d, hour: 8), status: .taken))
                if !isWed {
                    add(p.id, .medication, at: day(d, hour: 20, minute: 10), DosePayload(medicineID: DemoCircle.amlodipineDadID, scheduledAt: day(d, hour: 20), status: .taken))
                }
                add(p.id, .medication, at: day(d, hour: 20, minute: 40), DosePayload(medicineID: DemoCircle.metforminID, scheduledAt: day(d, hour: 20, minute: 30), status: d == 6 ? .skipped : .taken))
            }
            // Today's 8am Telmisartan is not marked yet, so at 09:41 it is a missed dose.

            let bp: [(Int, Int, Int)] = [(10, 132, 86), (8, 128, 84), (6, 136, 88), (4, 142, 92), (3, 134, 86), (1, 130, 84), (0, 138, 90)]
            for (d, s, dia) in bp {
                add(p.id, .health, at: day(d, hour: 7, minute: 45), HealthPayload(state: s >= 140 ? .neutral : .allGood, reading: HealthReading(kind: .bloodPressure, systolic: s, diastolic: dia)))
            }
            add(p.id, .health, at: day(5, hour: 7), HealthPayload(state: .allGood, reading: HealthReading(kind: .bloodSugar, value: 112, unit: "mg/dL", context: "fasting")))
            add(p.id, .health, at: day(12, hour: 7), HealthPayload(state: .allGood, reading: HealthReading(kind: .bloodSugar, value: 118, unit: "mg/dL", context: "fasting")))
            add(p.id, .health, at: day(2, hour: 21), HealthPayload(state: .neutral, symptoms: ["knee"], note: "Stairs at the temple"))

            event(p.id, .appointments, .health, "Dr. Iyer, cardiology review", start: date(2026, 9, 24, 10, 30), end: date(2026, 9, 24, 11, 15), location: "Apollo, Jubilee Hills",
                  payload: AppointmentDetails(doctor: "Dr. Iyer", specialty: "Cardiology", questions: ["Is 142/92 last Sunday a worry?", "Can the evening tablet move to morning?", "Fasting sugar 112, still pre-diabetic?"], bring: ["BP log", "Last ECG"]))
            event(p.id, .appointments, .health, "Dr. Iyer, cardiology", start: date(2026, 6, 12, 10), end: date(2026, 6, 12, 10, 40),
                  payload: AppointmentDetails(doctor: "Dr. Iyer", specialty: "Cardiology", summary: "BP stable on current dose. Walk 30 minutes daily. Recheck in 3 months."))
            event(p.id, .dates, .milestone, "Dad's birthday", start: date(1965, 1, 10), allDay: true, yearly: true)
            event(p.id, .dates, .milestone, "Parents' anniversary", start: date(1993, 5, 21), allDay: true, yearly: true)

            add(p.id, .mentions, at: day(7, hour: 19), MentionPayload(text: "Wants a new radio for the morning news", kind: .want))
            add(p.id, .mentions, at: day(3, hour: 20), MentionPayload(text: "Missing the morning walk since the knee started", kind: .worry))
            add(p.id, .callRhythm, at: day(1, hour: 19, minute: 10), CallPayload(durationMinutes: 18, note: "Knee better. Asked about Coorg."))
            add(p.id, .callRhythm, at: day(8, hour: 19), CallPayload(durationMinutes: 22))
        }

        // MARK: Kasi Annapurna (mother, BP medication, Sunday calls)

        mutating func buildAnnapurna() {
            var p = PersonRecord(id: DemoCircle.annapurnaID, name: "Kasi Annapurna", shortName: "Kasi", relationship: .parent, aura: .amberCoral,
                                 birthday: date(1969, 8, 3), homeCity: "Vijayawada", timeZoneIdentifier: "Asia/Kolkata",
                                 note: "Under BP medication. Calls every Sunday.", sortOrder: 3,
                                 enabledModules: [.mood, .health, .medication, .callRhythm, .appointments, .dates, .mentions])
            p.setSettings(MedicationSettings(medicines: [
                Medicine(id: DemoCircle.amlodipineMomID, name: "Amlodipine", dose: "5 mg", times: [TimeOfDay(hour: 9)], purpose: "Blood pressure", refillDate: date(2026, 10, 14)),
            ]), for: .medication)
            p.setSettings(CallRhythmSettings(weekday: 1, hour: 18), for: .callRhythm)   // Sundays 6pm
            people.append(p)

            for d in 1...14 {
                add(p.id, .medication, at: day(d, hour: 9, minute: 5), DosePayload(medicineID: DemoCircle.amlodipineMomID, scheduledAt: day(d, hour: 9), status: .taken))
            }
            // Six neutral days in a row. Usually "good".
            for (i, v) in [4, 4, 5, 4, 4, 4, 3, 3, 3, 3, 3, 3].enumerated() {
                add(p.id, .mood, at: day(11 - i, hour: 20), MoodPayload(value: v))
            }
            add(p.id, .health, at: day(9, hour: 8), HealthPayload(state: .allGood, reading: HealthReading(kind: .bloodPressure, systolic: 126, diastolic: 82)))
            add(p.id, .health, at: day(2, hour: 8), HealthPayload(state: .allGood, reading: HealthReading(kind: .bloodPressure, systolic: 130, diastolic: 84)))

            add(p.id, .mentions, at: day(10, hour: 18), MentionPayload(text: "Wants a new pressure cooker, the old one whistles wrong", kind: .want))
            add(p.id, .mentions, at: day(9, hour: 18), MentionPayload(text: "Her sister visits this Friday", kind: .fact))
            add(p.id, .mentions, at: day(9, hour: 18), MentionPayload(text: "Knee hurts on the temple stairs", kind: .worry))
            add(p.id, .callRhythm, at: day(9, hour: 18, minute: 20), CallPayload(durationMinutes: 34, note: "Talked about the sister's visit and Oreo."))
            add(p.id, .callRhythm, at: day(16, hour: 18, minute: 5), CallPayload(durationMinutes: 28))

            event(p.id, .appointments, .health, "Dr. Rao, general check", start: date(2026, 10, 2, 11), end: date(2026, 10, 2, 11, 30), location: "Vijayawada",
                  payload: AppointmentDetails(doctor: "Dr. Rao", specialty: "General medicine", questions: ["Knee pain on stairs", "BP log review"]))
            event(p.id, .dates, .milestone, "Mom's birthday", start: date(1969, 8, 3), allDay: true, yearly: true)
        }

        // MARK: Neeraj (brother)

        mutating func buildNeeraj() {
            let p = PersonRecord(id: DemoCircle.neerajID, name: "Neeraj", relationship: .sibling, aura: .violetLilac,
                                 birthday: date(2001, 12, 5), homeCity: "Bengaluru", timeZoneIdentifier: "Asia/Kolkata", sortOrder: 4,
                                 enabledModules: [.dates, .events, .mentions, .sharedChecklist, .wishlist])
            people.append(p)

            event(p.id, .events, .workAndSchool, "Final interview, Zoho", start: day(-1, hour: 11), end: day(-1, hour: 12), note: "Text good luck at 9am. He hates being asked before.")
            event(p.id, .events, .social, "Weekend in Hyderabad", start: date(2026, 9, 26, 10), end: date(2026, 9, 27, 20))
            event(p.id, .dates, .milestone, "Neeraj's birthday", start: date(2001, 12, 5), allDay: true, yearly: true)

            add(p.id, .mentions, at: day(13, hour: 22), MentionPayload(text: "Looking for a mechanical keyboard, wants brown switches", kind: .want))
            add(p.id, .mentions, at: day(5, hour: 21), MentionPayload(text: "Loves the biryani from Paradise, Secunderabad", kind: .like))
            add(p.id, .mentions, at: day(3, hour: 23), MentionPayload(text: "Nervous about the Zoho interview rounds", kind: .worry))
            add(p.id, .sharedChecklist, at: day(4), ChecklistItemPayload(text: "Send him the flat's WiFi password", done: true, doneAt: day(4), doneBy: "Surya"))
            add(p.id, .sharedChecklist, at: day(2), ChecklistItemPayload(text: "Split the Diwali gift for parents"))
            add(p.id, .wishlist, at: day(13), WishlistItemPayload(title: "Keychron K2, brown switches", price: 6999))
            add(p.id, .wishlist, at: day(30), WishlistItemPayload(title: "Running shoes, UK 9", price: 5499))
            add(p.id, .dates, at: date(2025, 12, 5), GiftPayload(eventID: events.first { $0.title == "Neeraj's birthday" }?.id ?? UUID(), year: 2025, gift: "Noise-cancelling earbuds"))
        }

        // MARK: Oreo (Shih Tzu)

        mutating func buildOreo() {
            var p = PersonRecord(id: DemoCircle.oreoID, name: "Oreo", relationship: .pet, aura: .honeyMint,
                                 birthday: date(2024, 2, 14), homeCity: "Hyderabad", note: "Shih Tzu. Yearly vet check, deworming every 3 months.", sortOrder: 5,
                                 enabledModules: [.petCare, .dates, .appointments])
            p.setSettings(PetCareSettings(species: "Dog", breed: "Shih Tzu", vetName: "Dr. Meera, Cessna Lifeline", vetPhone: "+91 40 0000 0000",
                                          foodBrand: "Royal Canin Shih Tzu Adult, 3 kg", foodDaysSupply: 30), for: .petCare)
            people.append(p)

            add(p.id, .petCare, at: date(2025, 10, 5), PetCarePayload(kind: .vetVisit, note: "Yearly check. All clear. Teeth to watch.", nextDue: date(2026, 10, 5)))
            add(p.id, .petCare, at: date(2025, 11, 2), PetCarePayload(kind: .vaccination, note: "DHPPi + rabies booster", nextDue: date(2026, 11, 2)))
            add(p.id, .petCare, at: date(2026, 7, 15), PetCarePayload(kind: .deworming, note: "Drontal, half tablet", nextDue: date(2026, 10, 15)))
            add(p.id, .petCare, at: date(2026, 8, 30), PetCarePayload(kind: .grooming, note: "Full trim, teddy cut", nextDue: date(2026, 10, 14)))
            add(p.id, .petCare, at: date(2026, 8, 22), PetCarePayload(kind: .foodOrder, note: "Royal Canin 3 kg", value: 2650))
            add(p.id, .petCare, at: date(2026, 9, 1), PetCarePayload(kind: .tickTreatment, note: "Bravecto spot-on", nextDue: date(2026, 10, 1)))
            add(p.id, .petCare, at: date(2026, 9, 10), PetCarePayload(kind: .medicine, note: "Ear drops, 5 days, done", medicineName: "Otiprin"))
            for (i, w) in [5.6, 5.8, 5.9, 6.1, 6.0].enumerated() {
                add(p.id, .petCare, at: day(120 - i * 30, hour: 10), PetCarePayload(kind: .weight, value: w))
            }
            event(p.id, .appointments, .health, "Vet: yearly check", start: date(2026, 10, 5, 11), end: date(2026, 10, 5, 11, 30), location: "Cessna Lifeline, Banjara Hills",
                  payload: AppointmentDetails(doctor: "Dr. Meera", specialty: "Veterinary", questions: ["Teeth cleaning this year?", "Weight 6.0 kg, ok for Shih Tzu?"], bring: ["Vaccination card"]))
            event(p.id, .dates, .milestone, "Oreo's gotcha day", start: date(2024, 2, 14), allDay: true, yearly: true)
        }
    }
}

/// Type-erasing wrapper so the fixture builder can attach any payload to an event.
struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}
