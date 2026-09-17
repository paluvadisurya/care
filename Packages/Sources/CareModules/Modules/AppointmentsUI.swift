import SwiftUI
import CareCore
import CareDesign
import CareData

public enum AppointmentsUI: ModuleUI {
    public static let id: ModuleID = .appointments

    public static func detail(person: PersonRecord) -> AnyView {
        AnyView(AppointmentsDetail(person: person))
    }
}

struct AppointmentsDetail: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var showAdd = false
    @State private var summaryFor: EventRecord?

    var body: some View {
        let ctx = store.context(for: person, module: .appointments)
        let upcoming = AppointmentsLogic.upcoming(ctx)
        let past = AppointmentsLogic.past(ctx)
        ModuleScreen(person: person, module: .appointments, actionTitle: "Book a visit", action: { showAdd = true }) {
            VStack(alignment: .leading, spacing: CareSpace.md) {
                if let next = upcoming.first {
                    BriefCard(person: person, event: next, now: ctx.now)
                }
                if upcoming.count > 1 {
                    CardSection("Later") {
                        ForEach(upcoming.dropFirst()) { e in
                            CardRow(symbol: "stethoscope", title: e.title, subtitle: e.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()), tint: ModuleAccent.color(for: .appointments))
                        }
                    }
                }
                if !past.isEmpty {
                    CardSection("Past visits", trailing: "\(past.count)") {
                        ForEach(past) { e in
                            let d = e.decode(AppointmentDetails.self)
                            CardRow(symbol: "checkmark.seal", title: e.title, subtitle: d?.summary ?? "Tap to add what was said", tint: CareColor.textMuted) {
                                Text(e.start.formatted(.dateTime.day().month(.abbreviated))).careType(.meta).foregroundStyle(CareColor.textMuted)
                            }
                            .onTapGesture { summaryFor = e }
                        }
                    }
                }
                if upcoming.isEmpty && past.isEmpty {
                    EmptyState(symbol: "stethoscope", title: "No visits yet", message: "Book one and Care prepares the questions to ask.")
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddAppointmentSheet(person: person) }
        .sheet(item: $summaryFor) { e in VisitSummarySheet(person: person, event: e) }
    }
}

struct BriefCard: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    let event: EventRecord
    let now: Date

    var body: some View {
        let d = event.decode(AppointmentDetails.self)
        let health = store.entries(for: person.id, module: .health).prefix(30).compactMap { $0.decode(HealthPayload.self)?.reading }
        let meds = person.settings(MedicationSettings.self, for: .medication)?.medicines ?? []
        VStack(alignment: .leading, spacing: CareSpace.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next visit").careType(.labelEmphasis).foregroundStyle(CareColor.textSecondary)
                    Text(event.title).careType(.cardTitle).displayTracking(20).foregroundStyle(CareColor.textPrimary)
                    Text("\(event.start.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))\(event.location.map { " · \($0)" } ?? "")").careType(.caption).foregroundStyle(CareColor.textMuted)
                }
                Spacer()
                Countdown(to: event.start, now: now, size: .large, showsHours: true)
            }
            if let d {
                if !d.questions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Questions to ask").careType(.label).foregroundStyle(CareColor.textSecondary)
                        ForEach(Array(d.questions.enumerated()), id: \.offset) { i, q in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(i + 1)").careType(.metaEmphasis).foregroundStyle(CareColor.violet).frame(width: 14)
                                Text(q).careType(.callout).foregroundStyle(CareColor.textPrimary)
                            }
                        }
                    }
                }
                if !d.bring.isEmpty {
                    Text("Bring: \(d.bring.joined(separator: ", "))").careType(.caption).foregroundStyle(CareColor.textSecondary)
                }
            }
            Divider().overlay(CareColor.separator)
            VStack(alignment: .leading, spacing: 4) {
                Text("Brief, built on device").careType(.label).foregroundStyle(CareColor.intelligence)
                if !meds.isEmpty { Text("Medicines: " + meds.map { "\($0.name) \($0.dose)" }.joined(separator: ", ")).careType(.caption).foregroundStyle(CareColor.textPrimary) }
                let bp = health.filter { $0.kind == .bloodPressure }.prefix(5)
                if !bp.isEmpty { Text("Recent BP: " + bp.map(\.label).joined(separator: ", ")).careType(.caption).foregroundStyle(CareColor.textPrimary) }
                let sugar = health.filter { $0.kind == .bloodSugar }.prefix(3)
                if !sugar.isEmpty { Text("Sugar: " + sugar.map(\.label).joined(separator: ", ")).careType(.caption).foregroundStyle(CareColor.textPrimary) }
            }
        }
        .careCard(radius: CareRadius.hero, padding: CareSpace.md + 2, strong: true)
    }
}

struct AddAppointmentSheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    @State private var title = ""
    @State private var doctor = ""
    @State private var specialty = ""
    @State private var location = ""
    @State private var start = CareDates.at(hour: 10, on: CareDates.adding(days: 7, to: .now))
    @State private var questions = ""

    var body: some View {
        SheetScaffold(title: "Book a visit", subtitle: person.shortName, aura: person.aura, primaryTitle: "Add", primaryEnabled: !title.isEmpty) {
            let qs = questions.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let details = AppointmentDetails(doctor: doctor, specialty: specialty, questions: qs)
            store.addEvent(EventRecord(personID: person.id, moduleID: .appointments, category: .health, title: title, start: start, end: CareDates.adding(hours: 1, to: start),
                                       location: location.isEmpty ? nil : location, payload: try? PayloadCoder.encode(details)))
        } content: {
            VStack(spacing: CareSpace.sm) {
                CareField("Visit", placeholder: "Dr. Iyer, cardiology review", text: $title)
                HStack(spacing: CareSpace.xs) {
                    CareField("Doctor", placeholder: "Dr. Iyer", text: $doctor)
                    CareField("Specialty", placeholder: "Cardiology", text: $specialty)
                }
                CareDateRow("When", date: $start)
                CareField("Where", placeholder: "Apollo, Jubilee Hills", text: $location)
                CareField("Questions to ask", placeholder: "One per line", text: $questions, axis: .vertical)
            }
        }
    }
}

struct VisitSummarySheet: View {
    @Environment(CareStore.self) private var store
    let person: PersonRecord
    let event: EventRecord
    @State private var summary: String

    init(person: PersonRecord, event: EventRecord) {
        self.person = person
        self.event = event
        self.summary = event.decode(AppointmentDetails.self)?.summary ?? ""
    }

    var body: some View {
        SheetScaffold(title: "What was said", subtitle: event.title, aura: person.aura, primaryTitle: "Save") {
            var e = event
            var d = e.decode(AppointmentDetails.self) ?? AppointmentDetails(doctor: "", specialty: "")
            d.summary = summary
            e.payload = try? PayloadCoder.encode(d)
            store.updateEvent(e)
        } content: {
            CareField("Summary", placeholder: "BP stable. Walk daily. Recheck in 3 months.", text: $summary, axis: .vertical)
        }
    }
}
