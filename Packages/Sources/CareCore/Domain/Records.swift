import Foundation

/// Who produced an entry.
public enum Author: String, Codable, Sendable, Hashable {
    /// The person logged it about themselves (only for the user's own profile in Phase 0).
    case selfReport
    /// The user logged it about someone else.
    case observed
}

/// Which rung of the input ladder the entry came from.
public enum EntrySource: String, Codable, Sendable, Hashable {
    case manual, notification, widget, siri, importCalendar, importPhotos, importHealth, ai, seed
}

/// One logged thing. The payload is module-owned JSON so every module evolves its own schema.
public struct EntryRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var personID: UUID
    public var moduleID: ModuleID
    public var occurredAt: Date
    public var author: Author
    public var source: EntrySource
    public var payload: Data
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(), personID: UUID, moduleID: ModuleID, occurredAt: Date,
        author: Author = .observed, source: EntrySource = .manual, payload: Data,
        tags: [String] = [], createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.personID = personID
        self.moduleID = moduleID
        self.occurredAt = occurredAt
        self.author = author
        self.source = source
        self.payload = payload
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Decode the module payload. Returns nil when the payload was written by a newer schema.
    public func decode<T: Decodable>(_ type: T.Type) -> T? {
        try? PayloadCoder.decode(type, from: payload)
    }
}

public enum PersonKind: String, Codable, Sendable {
    /// The user manages the profile fully (Phase 0: everyone).
    case managed
    /// The person has their own account and shares modules (Phase 1).
    case linked
}

/// A person in the circle. `enabledModules` and `moduleSettings` replace a separate ModuleInstance table for Phase 0.
public struct PersonRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var shortName: String
    public var relationship: Relationship
    public var kind: PersonKind
    public var aura: Aura
    public var birthday: Date?
    public var homeCity: String?
    public var timeZoneIdentifier: String?
    public var note: String?
    public var sortOrder: Int
    public var enabledModules: [ModuleID]
    public var moduleSettings: [ModuleID: Data]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(), name: String, shortName: String? = nil, relationship: Relationship,
        kind: PersonKind = .managed, aura: Aura, birthday: Date? = nil, homeCity: String? = nil,
        timeZoneIdentifier: String? = nil, note: String? = nil, sortOrder: Int = 0,
        enabledModules: [ModuleID]? = nil, moduleSettings: [ModuleID: Data] = [:],
        createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? PersonRecord.firstName(of: name)
        self.relationship = relationship
        self.kind = kind
        self.aura = aura
        self.birthday = birthday
        self.homeCity = homeCity
        self.timeZoneIdentifier = timeZoneIdentifier
        self.note = note
        self.sortOrder = sortOrder
        self.enabledModules = enabledModules ?? relationship.defaultModules
        self.moduleSettings = moduleSettings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func firstName(of name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Up to two initials for the orb.
    public var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    public func isEnabled(_ module: ModuleID) -> Bool { enabledModules.contains(module) }

    public func settings<T: Decodable>(_ type: T.Type, for module: ModuleID) -> T? {
        guard let data = moduleSettings[module] else { return nil }
        return try? PayloadCoder.decode(type, from: data)
    }

    public mutating func setSettings<T: Encodable>(_ value: T, for module: ModuleID) {
        if let data = try? PayloadCoder.encode(value) {
            moduleSettings[module] = data
            updatedAt = .now
        }
    }
}

public enum EventRecurrence: String, Codable, Sendable, Hashable {
    case none, yearly
}

/// Something happening in a person's life. Dates, appointments and trips are events owned by their module.
public struct EventRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var personID: UUID
    public var moduleID: ModuleID
    public var category: EventCategory
    public var title: String
    public var start: Date
    public var end: Date?
    public var isAllDay: Bool
    public var recurrence: EventRecurrence
    public var supportNote: String?
    public var location: String?
    public var leadTimes: [Int]
    public var followUp: Bool
    public var source: EntrySource
    public var payload: Data?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(), personID: UUID, moduleID: ModuleID = .events, category: EventCategory,
        title: String, start: Date, end: Date? = nil, isAllDay: Bool = false,
        recurrence: EventRecurrence = .none, supportNote: String? = nil, location: String? = nil,
        leadTimes: [Int]? = nil, followUp: Bool? = nil, source: EntrySource = .manual,
        payload: Data? = nil, createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.personID = personID
        self.moduleID = moduleID
        self.category = category
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.recurrence = recurrence
        self.supportNote = supportNote
        self.location = location
        self.leadTimes = leadTimes ?? category.defaults.leadTimeDays
        self.followUp = followUp ?? (category.defaults.followUp != nil)
        self.source = source
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let payload else { return nil }
        return try? PayloadCoder.decode(type, from: payload)
    }

    /// The next occurrence on or after `date`, honouring yearly recurrence.
    public func nextOccurrence(after date: Date, calendar: Calendar = .care) -> Date {
        guard recurrence == .yearly else { return start }
        let startDay = calendar.startOfDay(for: date)
        var comps = calendar.dateComponents([.month, .day], from: start)
        comps.year = calendar.component(.year, from: date)
        guard var candidate = calendar.date(from: comps) else { return start }
        if candidate < startDay {
            comps.year = (comps.year ?? 0) + 1
            candidate = calendar.date(from: comps) ?? candidate
        }
        return candidate
    }

    /// Years since the original date at the next occurrence. Nil when not recurring.
    public func yearsAt(_ date: Date, calendar: Calendar = .care) -> Int? {
        guard recurrence == .yearly else { return nil }
        let y1 = calendar.component(.year, from: start)
        let y2 = calendar.component(.year, from: nextOccurrence(after: date, calendar: calendar))
        return y2 - y1
    }
}

/// Feedback stored on a generated insight.
public enum InsightFeedback: String, Codable, Sendable {
    case up, down
}
