import Foundation

/// Inputs every module function receives. Entries and events are already filtered to this person.
public struct ModuleContext: Sendable {
    public var person: PersonRecord
    public var entries: [EntryRecord]      // this person, this module, newest first
    public var events: [EventRecord]       // this person, all modules
    public var allEntries: [EntryRecord]   // this person, all modules (for cross-module talking points)
    public var now: Date
    public var calendar: Calendar

    public init(person: PersonRecord, entries: [EntryRecord], events: [EventRecord], allEntries: [EntryRecord] = [],
                now: Date, calendar: Calendar = .care) {
        self.person = person
        self.entries = entries
        self.events = events
        self.allEntries = allEntries
        self.now = now
        self.calendar = calendar
    }

    public func entries(in window: DateInterval) -> [EntryRecord] {
        entries.filter { window.contains($0.occurredAt) }
    }

    public var todayEntries: [EntryRecord] {
        entries.filter { calendar.isDate($0.occurredAt, inSameDayAs: now) }
    }

    public func events(for module: ModuleID) -> [EventRecord] {
        events.filter { $0.moduleID == module }
    }
}

/// The non-visual half of a module. Pure functions over records so it runs in tests on any platform.
/// The visual half (tile, quick log, detail) lives in CareModules and is keyed by the same `ModuleID`.
public protocol ModuleLogic: Sendable {
    static var meta: ModuleMeta { get }
    static var allowedBlocks: Set<InsightBlockKind> { get }
    static var reminderRules: [ReminderRule] { get }

    static func todayState(_ ctx: ModuleContext) -> ModuleTodayState
    static func signals(_ ctx: ModuleContext) -> [Signal]
    static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack?
    static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate]
    static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem]
}

public extension ModuleLogic {
    static var id: ModuleID { meta.id }
    static var allowedBlocks: Set<InsightBlockKind> { [.headline, .stat, .list, .insight, .action, .note] }
    static var reminderRules: [ReminderRule] { [] }
    static func signals(_ ctx: ModuleContext) -> [Signal] { [] }
    static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? { nil }
    static func reminderCandidates(_ ctx: ModuleContext) -> [ReminderCandidate] { [] }
    static func timelineItems(_ ctx: ModuleContext, day: Date) -> [TimelineItem] { [] }
}
