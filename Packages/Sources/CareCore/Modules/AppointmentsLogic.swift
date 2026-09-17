import Foundation

/// Extra detail stored on a health event owned by the Appointments module.
public struct AppointmentDetails: Codable, Hashable, Sendable {
    public var doctor: String
    public var specialty: String
    public var questions: [String]
    public var summary: String?         // what was said, filled after the visit
    public var bring: [String]

    public init(doctor: String, specialty: String, questions: [String] = [], summary: String? = nil, bring: [String] = []) {
        self.doctor = doctor
        self.specialty = specialty
        self.questions = questions
        self.summary = summary
        self.bring = bring
    }
}

public enum AppointmentsLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.appointments)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .countdown, .list, .talkingPoints, .action, .note]
    public static let reminderRules = [
        ReminderRule(id: "appointments.before", kind: .eventBefore, description: "The evening before, with the prep brief"),
        ReminderRule(id: "appointments.after", kind: .eventAfter, description: "Same evening: how did it go?"),
    ]

    public static func upcoming(_ ctx: ModuleContext) -> [EventRecord] {
        ctx.events(for: .appointments).filter { $0.start >= ctx.calendar.startOfDay(for: ctx.now) }.sorted { $0.start < $1.start }
    }

    public static func past(_ ctx: ModuleContext) -> [EventRecord] {
        ctx.events(for: .appointments).filter { $0.start < ctx.calendar.startOfDay(for: ctx.now) }.sorted { $0.start > $1.start }
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        guard let next = upcoming(ctx).first else {
            return ModuleTodayState(headline: "No visit booked", detail: past(ctx).first.map { "Last: \($0.title)" } ?? "Add one")
        }
        let d = CareDates.daysBetween(ctx.now, next.start, calendar: ctx.calendar)
        let details = next.decode(AppointmentDetails.self)
        return ModuleTodayState(headline: d == 0 ? CareDates.timeLabel(next.start, calendar: ctx.calendar) : "\(d)d",
                                detail: details.map { "\($0.doctor) · \(ModuleHelpers.plural($0.questions.count, "question"))" } ?? next.title,
                                tone: d <= 1 ? .upcoming : .neutral)
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        return upcoming(ctx).compactMap { e in
            let d = CareDates.daysBetween(ctx.now, e.start, calendar: ctx.calendar)
            guard d <= 1 else { return nil }
            let details = e.decode(AppointmentDetails.self)
            let q = details?.questions.count ?? 0
            return Signal(
                id: ModuleHelpers.signalID(.appointments, .appointmentPrep, p.id, suffix: e.id.uuidString.prefix(6).description),
                personID: p.id, moduleID: .appointments, kind: .appointmentPrep,
                title: "\(p.shortName). \(e.title)", body: d == 0 ? "\(CareDates.timeLabel(e.start, calendar: ctx.calendar)). \(ModuleHelpers.plural(q, "question")) saved." : "Tomorrow. \(ModuleHelpers.plural(q, "question")) saved, brief ready.",
                at: e.start, priority: 0.6, tone: .upcoming, hero: .countdown(e.start),
                actions: [SignalAction(title: "Open brief", link: .module(personID: p.id, module: .appointments), isPrimary: true)])
        }
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let next = upcoming(ctx).first
        let last = past(ctx).first
        guard next != nil || last != nil else { return nil }
        func row(_ e: EventRecord) -> JSONValue {
            let d = e.decode(AppointmentDetails.self)
            return .object(["title": .string(e.title), "date": .date(e.start), "doctor": .optional(d?.doctor), "specialty": .optional(d?.specialty),
                            "questions": .array((d?.questions ?? []).map { .string($0) }), "summary": .optional(d?.summary)])
        }
        return ContextPack(moduleID: .appointments, summary: next.map { "next visit \(CareDates.relativeDays(from: ctx.now, to: $0.start))" } ?? "no visit booked",
                           data: .object(["next": next.map(row) ?? .null, "last": last.map(row) ?? .null]), privateToUser: true)
    }

    public static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] {
        let p = ctx.person
        return upcoming(ctx).compactMap { e in
            let d = CareDates.daysBetween(ctx.now, e.start, calendar: ctx.calendar)
            guard d == 1 else { return nil }
            return ReminderCandidate(
                id: "appointments.before.\(e.id.uuidString.prefix(8))", personID: p.id, moduleID: .appointments, kind: .eventBefore,
                earliest: CareDates.at(hour: 18, on: ctx.now, calendar: ctx.calendar), latest: CareDates.at(hour: 20, on: ctx.now, calendar: ctx.calendar),
                priority: 0.6, message: "\(p.shortName)'s \(e.title) is tomorrow at \(CareDates.timeLabel(e.start, calendar: ctx.calendar)).", reason: "Brief and questions ready",
                actions: [ReminderAction(id: "brief", title: "Open brief")], link: .module(personID: p.id, module: .appointments))
        }
    }

    public static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] {
        ctx.events(for: .appointments).filter { ctx.calendar.isDate($0.start, inSameDayAs: day) }.map { e in
            let d = e.decode(AppointmentDetails.self)
            return TimelineItem(id: "appt.\(e.id.uuidString.prefix(8))", personID: ctx.person.id, moduleID: .appointments, title: e.title,
                                subtitle: "\(ctx.person.shortName) · \(d.map { ModuleHelpers.plural($0.questions.count, "question") + " saved" } ?? "Appointment")",
                                start: e.start, end: e.end, source: e.source == .importCalendar ? .appleCalendar : .care, tone: .attention,
                                link: .module(personID: ctx.person.id, module: .appointments))
        }
    }
}
