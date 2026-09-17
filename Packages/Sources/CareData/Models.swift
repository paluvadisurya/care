import Foundation
import SwiftData
import CareCore
import CareIntelligence

// SwiftData rows. Every model has a UUID id, timestamps and a soft delete so CloudKit sync can be switched on later
// without a migration. Module payloads are JSON blobs owned by their module.

@Model
public final class PersonModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var shortName: String
    public var relationshipRaw: String
    public var kindRaw: String
    public var auraName: String
    public var auraStart: String
    public var auraEnd: String
    public var birthday: Date?
    public var homeCity: String?
    public var timeZoneIdentifier: String?
    public var note: String?
    public var sortOrder: Int
    public var enabledModulesRaw: [String]
    public var moduleSettingsJSON: Data
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(record: PersonRecord) {
        id = record.id
        name = record.name
        shortName = record.shortName
        relationshipRaw = record.relationship.rawValue
        kindRaw = record.kind.rawValue
        auraName = record.aura.name
        auraStart = record.aura.start
        auraEnd = record.aura.end
        birthday = record.birthday
        homeCity = record.homeCity
        timeZoneIdentifier = record.timeZoneIdentifier
        note = record.note
        sortOrder = record.sortOrder
        enabledModulesRaw = record.enabledModules.map(\.rawValue)
        moduleSettingsJSON = (try? PayloadCoder.encode(record.moduleSettings.reduce(into: [String: Data]()) { $0[$1.key.rawValue] = $1.value })) ?? Data()
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    public func apply(_ record: PersonRecord) {
        name = record.name
        shortName = record.shortName
        relationshipRaw = record.relationship.rawValue
        kindRaw = record.kind.rawValue
        auraName = record.aura.name
        auraStart = record.aura.start
        auraEnd = record.aura.end
        birthday = record.birthday
        homeCity = record.homeCity
        timeZoneIdentifier = record.timeZoneIdentifier
        note = record.note
        sortOrder = record.sortOrder
        enabledModulesRaw = record.enabledModules.map(\.rawValue)
        moduleSettingsJSON = (try? PayloadCoder.encode(record.moduleSettings.reduce(into: [String: Data]()) { $0[$1.key.rawValue] = $1.value })) ?? Data()
        updatedAt = .now
    }

    public var record: PersonRecord {
        let settingsRaw = (try? PayloadCoder.decode([String: Data].self, from: moduleSettingsJSON)) ?? [:]
        var settings: [ModuleID: Data] = [:]
        for (k, v) in settingsRaw { if let id = ModuleID(rawValue: k) { settings[id] = v } }
        return PersonRecord(
            id: id, name: name, shortName: shortName, relationship: Relationship(rawValue: relationshipRaw) ?? .other,
            kind: PersonKind(rawValue: kindRaw) ?? .managed, aura: Aura(name: auraName, start: auraStart, end: auraEnd),
            birthday: birthday, homeCity: homeCity, timeZoneIdentifier: timeZoneIdentifier, note: note, sortOrder: sortOrder,
            enabledModules: enabledModulesRaw.compactMap(ModuleID.init(rawValue:)), moduleSettings: settings,
            createdAt: createdAt, updatedAt: updatedAt)
    }
}

@Model
public final class EntryModel {
    @Attribute(.unique) public var id: UUID
    public var personID: UUID
    public var moduleRaw: String
    public var occurredAt: Date
    public var authorRaw: String
    public var sourceRaw: String
    public var payload: Data
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(record: EntryRecord) {
        id = record.id
        personID = record.personID
        moduleRaw = record.moduleID.rawValue
        occurredAt = record.occurredAt
        authorRaw = record.author.rawValue
        sourceRaw = record.source.rawValue
        payload = record.payload
        tags = record.tags
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    public func apply(_ record: EntryRecord) {
        occurredAt = record.occurredAt
        authorRaw = record.author.rawValue
        sourceRaw = record.source.rawValue
        payload = record.payload
        tags = record.tags
        updatedAt = .now
    }

    public var record: EntryRecord? {
        guard let module = ModuleID(rawValue: moduleRaw) else { return nil }
        return EntryRecord(id: id, personID: personID, moduleID: module, occurredAt: occurredAt, author: Author(rawValue: authorRaw) ?? .observed,
                           source: EntrySource(rawValue: sourceRaw) ?? .manual, payload: payload, tags: tags, createdAt: createdAt, updatedAt: updatedAt)
    }
}

@Model
public final class EventModel {
    @Attribute(.unique) public var id: UUID
    public var personID: UUID
    public var moduleRaw: String
    public var categoryRaw: String
    public var title: String
    public var start: Date
    public var end: Date?
    public var isAllDay: Bool
    public var recurrenceRaw: String
    public var supportNote: String?
    public var location: String?
    public var leadTimes: [Int]
    public var followUp: Bool
    public var sourceRaw: String
    public var payload: Data?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(record: EventRecord) {
        id = record.id
        personID = record.personID
        moduleRaw = record.moduleID.rawValue
        categoryRaw = record.category.rawValue
        title = record.title
        start = record.start
        end = record.end
        isAllDay = record.isAllDay
        recurrenceRaw = record.recurrence.rawValue
        supportNote = record.supportNote
        location = record.location
        leadTimes = record.leadTimes
        followUp = record.followUp
        sourceRaw = record.source.rawValue
        payload = record.payload
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    public func apply(_ record: EventRecord) {
        moduleRaw = record.moduleID.rawValue
        categoryRaw = record.category.rawValue
        title = record.title
        start = record.start
        end = record.end
        isAllDay = record.isAllDay
        recurrenceRaw = record.recurrence.rawValue
        supportNote = record.supportNote
        location = record.location
        leadTimes = record.leadTimes
        followUp = record.followUp
        payload = record.payload
        updatedAt = .now
    }

    public var record: EventRecord {
        EventRecord(id: id, personID: personID, moduleID: ModuleID(rawValue: moduleRaw) ?? .events, category: EventCategory(rawValue: categoryRaw) ?? .personal,
                    title: title, start: start, end: end, isAllDay: isAllDay, recurrence: EventRecurrence(rawValue: recurrenceRaw) ?? .none,
                    supportNote: supportNote, location: location, leadTimes: leadTimes, followUp: followUp, source: EntrySource(rawValue: sourceRaw) ?? .manual,
                    payload: payload, createdAt: createdAt, updatedAt: updatedAt)
    }
}

@Model
public final class InsightModel {
    @Attribute(.unique) public var id: UUID
    public var scopeRaw: String
    public var scopeID: UUID?
    public var generatedAt: Date
    public var expiresAt: Date
    public var modelID: String
    public var originRaw: String
    public var inputHash: String
    public var insightJSON: Data
    public var feedbackRaw: String?
    public var refreshNote: String?

    public init(record: InsightRecord) {
        id = record.id
        scopeRaw = record.scope.rawValue
        scopeID = record.scopeID
        generatedAt = record.generatedAt
        expiresAt = record.expiresAt
        modelID = record.modelID
        originRaw = record.origin.rawValue
        inputHash = record.inputHash
        insightJSON = (try? PayloadCoder.encode(record.insight)) ?? Data()
        feedbackRaw = record.feedback?.rawValue
        refreshNote = record.refreshNote
    }

    public func apply(_ record: InsightRecord) {
        generatedAt = record.generatedAt
        expiresAt = record.expiresAt
        modelID = record.modelID
        originRaw = record.origin.rawValue
        inputHash = record.inputHash
        insightJSON = (try? PayloadCoder.encode(record.insight)) ?? Data()
        feedbackRaw = record.feedback?.rawValue
        refreshNote = record.refreshNote
    }

    public var record: InsightRecord? {
        guard let scope = ScopeContext.Scope(rawValue: scopeRaw), let insight = try? PayloadCoder.decode(Insight.self, from: insightJSON) else { return nil }
        return InsightRecord(id: id, scope: scope, scopeID: scopeID, generatedAt: generatedAt, expiresAt: expiresAt, modelID: modelID,
                             origin: InsightOrigin(rawValue: originRaw) ?? .local, inputHash: inputHash, insight: insight,
                             feedback: feedbackRaw.flatMap(InsightFeedback.init(rawValue:)), refreshNote: refreshNote)
    }
}

public enum CareModelContainer {
    public static let schema = Schema([PersonModel.self, EntryModel.self, EventModel.self, InsightModel.self])

    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration("Care", schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
