import Foundation

/// The block vocabulary an insight may contain. Modules declare which kinds they allow.
public enum InsightBlockKind: String, Codable, CaseIterable, Sendable, Hashable {
    case headline, stat, trend, countdown, list, action, insight, moodStrip = "mood_strip",
         talkingPoints = "talking_points", compare, note
}

/// A compact, model-readable summary of one module for one person over a window. Never raw history.
public struct ContextPack: Codable, Hashable, Sendable {
    public var moduleID: ModuleID
    public var summary: String          // one line a human could read
    public var data: JSONValue          // compact structured data for the model
    public var privateToUser: Bool      // the model must not phrase this as if the person said it
    public var evidenceIDs: [String]    // entry ids the model may cite

    public init(moduleID: ModuleID, summary: String, data: JSONValue, privateToUser: Bool = false, evidenceIDs: [String] = []) {
        self.moduleID = moduleID
        self.summary = summary
        self.data = data
        self.privateToUser = privateToUser
        self.evidenceIDs = evidenceIDs
    }
}

/// Everything the model receives for one scope. Built by the intelligence layer from module packs.
public struct ScopeContext: Codable, Hashable, Sendable {
    public enum Scope: String, Codable, Sendable { case person, module, home, weekly }

    public var scope: Scope
    public var today: String
    public var userName: String
    public var timeZone: String
    public var quietHours: [String]
    public var person: PersonBrief?
    public var people: [PersonBrief]
    public var allowedModules: [ModuleID]
    public var allowedBlocks: [InsightBlockKind]
    public var windowFrom: String
    public var windowTo: String
    public var packs: [ContextPack]
    public var previousHeadline: String?
    public var previousFeedback: InsightFeedback?

    public init(
        scope: Scope, today: String, userName: String, timeZone: String, quietHours: [String],
        person: PersonBrief?, people: [PersonBrief], allowedModules: [ModuleID], allowedBlocks: [InsightBlockKind],
        windowFrom: String, windowTo: String, packs: [ContextPack], previousHeadline: String? = nil,
        previousFeedback: InsightFeedback? = nil
    ) {
        self.scope = scope
        self.today = today
        self.userName = userName
        self.timeZone = timeZone
        self.quietHours = quietHours
        self.person = person
        self.people = people
        self.allowedModules = allowedModules
        self.allowedBlocks = allowedBlocks
        self.windowFrom = windowFrom
        self.windowTo = windowTo
        self.packs = packs
        self.previousHeadline = previousHeadline
        self.previousFeedback = previousFeedback
    }
}

/// The minimum the model needs to know about a person. First name only, never photos.
public struct PersonBrief: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var relationship: Relationship
    public var aura: String

    public init(_ person: PersonRecord) {
        id = person.id.uuidString
        name = person.shortName
        relationship = person.relationship
        aura = person.aura.name
    }
}
