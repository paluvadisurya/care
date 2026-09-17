import Foundation

/// Semantic tone. Coral means attention, amber upcoming, mint positive, violet intelligence.
public enum Tone: String, Codable, Sendable, Hashable {
    case attention, upcoming, positive, neutral
}

public enum SignalKind: String, Codable, Sendable, Hashable, CaseIterable {
    case missedDose, doseDue, refillSoon
    case checkInDue, lowStreak, symptomStreak, readingHigh
    case eventSoon, eventFollowUp, appointmentPrep
    case dateSoon
    case hydrationBehind
    case worryUnresolved, promiseDue, promiseStale, checklistStale, checklistDue
    case callRhythm
    case travelSoon, travelAway
    case petCareDue, petFoodLow
    case wishlistInBudget
    case quietWeek
}

/// How Today renders a signal when it wins the hero slot.
public enum HeroPresentation: Hashable, Sendable, Codable {
    case numeral(value: String, unit: String)
    case countdown(Date)
    case word(String)
    case plain
}

public struct SignalAction: Hashable, Sendable, Codable, Identifiable {
    public enum Kind: String, Codable, Sendable { case open, log, call, message, snooze, markTaken, done, remindLater }

    public var id: String { title + link.url.absoluteString }
    public var title: String
    public var kind: Kind
    public var link: DeepLink
    public var isPrimary: Bool

    public init(title: String, kind: Kind = .open, link: DeepLink, isPrimary: Bool = false) {
        self.title = title
        self.kind = kind
        self.link = link
        self.isPrimary = isPrimary
    }
}

/// One thing that may need the user. Modules emit these; HomeRanker orders them across everyone.
public struct Signal: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var personID: UUID
    public var moduleID: ModuleID
    public var kind: SignalKind
    public var title: String
    public var body: String
    public var at: Date?
    public var priority: Double       // 0...1 from the module, before ranking
    public var tone: Tone
    public var hero: HeroPresentation
    public var actions: [SignalAction]

    public init(
        id: String, personID: UUID, moduleID: ModuleID, kind: SignalKind, title: String, body: String,
        at: Date? = nil, priority: Double, tone: Tone = .neutral, hero: HeroPresentation = .plain,
        actions: [SignalAction] = []
    ) {
        self.id = id
        self.personID = personID
        self.moduleID = moduleID
        self.kind = kind
        self.title = title
        self.body = body
        self.at = at
        self.priority = priority
        self.tone = tone
        self.hero = hero
        self.actions = actions
    }
}

/// A single row in the merged day view.
public struct TimelineItem: Identifiable, Hashable, Sendable {
    public enum Source: String, Sendable { case care, appleCalendar, appleReminders }

    public var id: String
    public var personID: UUID?
    public var moduleID: ModuleID?
    public var title: String
    public var subtitle: String
    public var start: Date
    public var end: Date?
    public var isAllDay: Bool
    public var source: Source
    public var tone: Tone
    public var link: DeepLink?
    public var isDone: Bool

    public init(
        id: String, personID: UUID?, moduleID: ModuleID?, title: String, subtitle: String, start: Date,
        end: Date? = nil, isAllDay: Bool = false, source: Source = .care, tone: Tone = .neutral,
        link: DeepLink? = nil, isDone: Bool = false
    ) {
        self.id = id
        self.personID = personID
        self.moduleID = moduleID
        self.title = title
        self.subtitle = subtitle
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.source = source
        self.tone = tone
        self.link = link
        self.isDone = isDone
    }
}

/// What a module's bento tile shows today. Pure data; CareModules turns it into a view.
public struct ModuleTodayState: Hashable, Sendable {
    public var headline: String        // "Good", "2 of 2", "0.5 L"
    public var detail: String          // "Checked in 2h ago"
    public var progress: Double?       // 0...1 for rings
    public var tone: Tone
    public var trail: [Int?]           // last 14 days, 1...5, for strips
    public var needsAttention: Bool

    public init(headline: String, detail: String, progress: Double? = nil, tone: Tone = .neutral,
                trail: [Int?] = [], needsAttention: Bool = false) {
        self.headline = headline
        self.detail = detail
        self.progress = progress
        self.tone = tone
        self.trail = trail
        self.needsAttention = needsAttention
    }

    public static let empty = ModuleTodayState(headline: "—", detail: "Nothing yet")
}
