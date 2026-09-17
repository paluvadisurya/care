import Foundation

public enum ReminderKind: String, Codable, Sendable, Hashable, CaseIterable {
    case morningBrief, pulseCheck, eventBefore, eventAfter, date, medication, refill, hydration,
         callRhythm, signal, travel, eveningWrap, petCare, promise, checklist
}

public enum InterruptionLevel: String, Codable, Sendable {
    case active, timeSensitive
}

public struct ReminderAction: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var link: DeepLink?

    public init(id: String, title: String, link: DeepLink? = nil) {
        self.id = id
        self.title = title
        self.link = link
    }
}

/// A reminder a module would like to send. The planner picks the time and words; guardrails have the last say.
public struct ReminderCandidate: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var personID: UUID
    public var moduleID: ModuleID
    public var kind: ReminderKind
    public var earliest: Date
    public var latest: Date
    public var priority: Double
    public var message: String
    public var reason: String
    public var actions: [ReminderAction]
    public var interruption: InterruptionLevel
    public var link: DeepLink
    public var contextIDs: [String]

    public init(
        id: String, personID: UUID, moduleID: ModuleID, kind: ReminderKind, earliest: Date, latest: Date,
        priority: Double, message: String, reason: String, actions: [ReminderAction] = [],
        interruption: InterruptionLevel = .active, link: DeepLink, contextIDs: [String] = []
    ) {
        self.id = id
        self.personID = personID
        self.moduleID = moduleID
        self.kind = kind
        self.earliest = earliest
        self.latest = latest
        self.priority = priority
        self.message = message
        self.reason = reason
        self.actions = actions
        self.interruption = interruption
        self.link = link
        self.contextIDs = contextIDs
    }
}

/// A human-readable rule description, rendered in the store and used by tests.
public struct ReminderRule: Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: ReminderKind
    public var description: String

    public init(id: String, kind: ReminderKind, description: String) {
        self.id = id
        self.kind = kind
        self.description = description
    }
}
