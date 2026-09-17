import Foundation

/// Day-of nudge timing for an event category.
public enum DayOfTiming: String, Codable, Sendable, Hashable {
    case morning
    case twoHoursBefore
    case oneHourBefore
    case atStart
}

/// When the "how did it go?" nudge fires.
public enum FollowUpTiming: String, Codable, Sendable, Hashable {
    case oneHourAfter
    case sameEvening
    case sameDay
    case arrivalAndReturn
}

public struct EventCategoryDefaults: Hashable, Sendable {
    public var leadTimeDays: [Int]
    public var dayOf: DayOfTiming
    public var followUp: FollowUpTiming?
    public var suggestedAction: String

    public init(leadTimeDays: [Int], dayOf: DayOfTiming, followUp: FollowUpTiming?, suggestedAction: String) {
        self.leadTimeDays = leadTimeDays
        self.dayOf = dayOf
        self.followUp = followUp
        self.suggestedAction = suggestedAction
    }
}

/// The seven-category taxonomy. The category decides default reminders, the support action and the follow-up.
public enum EventCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case milestone
    case health
    case workAndSchool
    case travel
    case social
    case faithAndCulture
    case personal

    public var displayName: String {
        switch self {
        case .milestone: "Milestone"
        case .health: "Health"
        case .workAndSchool: "Work and school"
        case .travel: "Travel"
        case .social: "Social"
        case .faithAndCulture: "Faith and culture"
        case .personal: "Personal"
        }
    }

    public var symbol: String {
        switch self {
        case .milestone: "sparkles"
        case .health: "cross.case"
        case .workAndSchool: "graduationcap"
        case .travel: "airplane"
        case .social: "party.popper"
        case .faithAndCulture: "flame"
        case .personal: "figure.run"
        }
    }

    public var examples: String {
        switch self {
        case .milestone: "Birthday, anniversary, graduation, promotion, new home"
        case .health: "Appointment, surgery, test, scan"
        case .workAndSchool: "Exam, interview, presentation, deadline, review"
        case .travel: "Trip, flight, return"
        case .social: "Wedding, party, dinner, reunion"
        case .faithAndCulture: "Festivals, fasting periods, holidays"
        case .personal: "Race, performance, first day, goal date"
        }
    }

    public var defaults: EventCategoryDefaults {
        switch self {
        case .milestone:
            EventCategoryDefaults(leadTimeDays: [14, 3], dayOf: .morning, followUp: nil,
                                  suggestedAction: "Gift from wishlist, message, plan")
        case .health:
            EventCategoryDefaults(leadTimeDays: [1], dayOf: .twoHoursBefore, followUp: .sameEvening,
                                  suggestedAction: "Go with them, call after")
        case .workAndSchool:
            EventCategoryDefaults(leadTimeDays: [1], dayOf: .oneHourBefore, followUp: .oneHourAfter,
                                  suggestedAction: "Good-luck message, light evening")
        case .travel:
            EventCategoryDefaults(leadTimeDays: [7, 1], dayOf: .atStart, followUp: .arrivalAndReturn,
                                  suggestedAction: "Packing list, weather, pause other nudges")
        case .social:
            EventCategoryDefaults(leadTimeDays: [3], dayOf: .morning, followUp: nil,
                                  suggestedAction: "Gift, outfit, RSVP")
        case .faithAndCulture:
            EventCategoryDefaults(leadTimeDays: [3], dayOf: .morning, followUp: nil,
                                  suggestedAction: "Greeting, visit, food")
        case .personal:
            EventCategoryDefaults(leadTimeDays: [1], dayOf: .oneHourBefore, followUp: .sameDay,
                                  suggestedAction: "Encouragement, show up")
        }
    }

    /// On-device classification from a title. Keyword based; a Foundation Models pass can replace it later.
    public static func classify(title: String) -> EventCategory {
        let t = title.lowercased()
        func hit(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        if hit(["birthday", "anniversary", "graduat", "promotion", "new home", "housewarming", "baby", "retire", "wedding day"]) { return .milestone }
        if hit(["doctor", "dr.", "dr ", "clinic", "hospital", "scan", "surgery", "test", "dentist", "vet", "check-up", "checkup", "cardio", "diabet", "bp "]) { return .health }
        if hit(["exam", "interview", "presentation", "deadline", "review", "class", "lecture", "meeting", "demo", "launch"]) { return .workAndSchool }
        if hit(["trip", "flight", "travel", "return", "holiday", "vacation", "train", "airport"]) { return .travel }
        if hit(["wedding", "party", "dinner", "reunion", "lunch", "brunch", "drinks", "concert", "movie"]) { return .social }
        if hit(["diwali", "pongal", "sankranti", "ugadi", "eid", "christmas", "puja", "pooja", "festival", "fast", "navratri", "dussehra", "ganesh", "holi"]) { return .faithAndCulture }
        return .personal
    }
}
