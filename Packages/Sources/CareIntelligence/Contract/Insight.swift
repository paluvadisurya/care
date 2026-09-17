import Foundation
import CareCore

public enum InsightTone: String, Codable, Sendable, Hashable { case positive, neutral, attention }

/// A reminder the model proposes. Guardrails validate before anything is scheduled.
public struct ProposedReminder: Codable, Hashable, Sendable {
    public var fireAt: String       // ISO 8601 local time
    public var message: String
    public var reason: String
    public var module: String
    public var personID: String

    public init(fireAt: String, message: String, reason: String, module: String, personID: String) {
        self.fireAt = fireAt
        self.message = message
        self.reason = reason
        self.module = module
        self.personID = personID
    }

    enum CodingKeys: String, CodingKey { case fireAt = "fire_at", message, reason, module, personID = "person_id" }
}

/// The care_insight contract. The model never returns prose alone; it returns this.
public struct Insight: Codable, Hashable, Sendable {
    public var scope: ScopeContext.Scope
    public var tone: InsightTone
    public var headline: String
    public var blocks: [InsightBlock]
    public var reminders: [ProposedReminder]
    public var evidence: [String]

    public init(scope: ScopeContext.Scope, tone: InsightTone, headline: String, blocks: [InsightBlock],
                reminders: [ProposedReminder] = [], evidence: [String] = []) {
        self.scope = scope
        self.tone = tone
        self.headline = headline
        self.blocks = blocks
        self.reminders = reminders
        self.evidence = evidence
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scope = try c.decodeIfPresent(ScopeContext.Scope.self, forKey: .scope) ?? .person
        tone = try c.decodeIfPresent(InsightTone.self, forKey: .tone) ?? .neutral
        headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? ""
        blocks = try c.decodeIfPresent([InsightBlock].self, forKey: .blocks) ?? []
        reminders = try c.decodeIfPresent([ProposedReminder].self, forKey: .reminders) ?? []
        evidence = try c.decodeIfPresent([String].self, forKey: .evidence) ?? []
    }

    enum CodingKeys: String, CodingKey { case scope, tone, headline, blocks, reminders, evidence }

    public var action: InsightBlock? {
        blocks.first { if case .action = $0 { return true } else { return false } }
    }
}

/// Where an insight came from.
public enum InsightOrigin: String, Codable, Sendable, Hashable {
    case model      // a language model wrote it
    case local      // the on-device rule engine wrote it (no key, or offline)
}

/// A stored, cached insight. Mirrors the SwiftData row in CareData.
public struct InsightRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var scope: ScopeContext.Scope
    public var scopeID: UUID?
    public var generatedAt: Date
    public var expiresAt: Date
    public var modelID: String
    public var origin: InsightOrigin
    public var inputHash: String
    public var insight: Insight
    public var feedback: InsightFeedback?
    public var refreshNote: String?

    public init(id: UUID = UUID(), scope: ScopeContext.Scope, scopeID: UUID?, generatedAt: Date, expiresAt: Date,
                modelID: String, origin: InsightOrigin, inputHash: String, insight: Insight,
                feedback: InsightFeedback? = nil, refreshNote: String? = nil) {
        self.id = id
        self.scope = scope
        self.scopeID = scopeID
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
        self.modelID = modelID
        self.origin = origin
        self.inputHash = inputHash
        self.insight = insight
        self.feedback = feedback
        self.refreshNote = refreshNote
    }

    public func isExpired(at now: Date) -> Bool { now >= expiresAt }
}
