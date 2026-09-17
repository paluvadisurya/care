import Foundation

public struct ChecklistItemPayload: Codable, Hashable, Sendable {
    public var text: String
    public var done: Bool
    public var doneAt: Date?
    public var doneBy: String?
    public var dueDate: Date?
    public init(text: String, done: Bool = false, doneAt: Date? = nil, doneBy: String? = nil, dueDate: Date? = nil) {
        self.text = text
        self.done = done
        self.doneAt = doneAt
        self.doneBy = doneBy
        self.dueDate = dueDate
    }
}

public enum SharedChecklistLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.sharedChecklist)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .stat, .compare, .list, .action, .note]
    public static let reminderRules = [
        ReminderRule(id: "checklist.due", kind: .checklist, description: "Due items, and anything stuck for 14 days"),
    ]

    public static func open(_ ctx: ModuleContext) -> [(EntryRecord, ChecklistItemPayload)] {
        ctx.entries.compactMap { e -> (EntryRecord, ChecklistItemPayload)? in
            guard let item = e.decode(ChecklistItemPayload.self), !item.done else { return nil }
            return (e, item)
        }
    }

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        let open = open(ctx)
        guard !open.isEmpty else { return ModuleTodayState(headline: "All clear", detail: "Nothing open", tone: .positive) }
        return ModuleTodayState(headline: "\(open.count) open", detail: open.prefix(3).map { $0.1.text }.joined(separator: ", "))
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        var out: [Signal] = []
        let due = open(ctx).filter { if let d = $0.1.dueDate { return CareDates.daysBetween(ctx.now, d, calendar: ctx.calendar) <= 0 } else { return false } }
        if let first = due.first {
            out.append(Signal(id: ModuleHelpers.signalID(.sharedChecklist, .checklistDue, p.id), personID: p.id, moduleID: .sharedChecklist, kind: .checklistDue,
                              title: "With \(p.shortName). \(first.1.text)", body: due.count > 1 ? "\(due.count) items due." : "Due today.",
                              at: first.1.dueDate, priority: 0.4, tone: .upcoming,
                              actions: [SignalAction(title: "Done", kind: .done, link: .module(personID: p.id, module: .sharedChecklist), isPrimary: true)]))
        }
        let stale = open(ctx).filter { CareDates.daysBetween($0.0.occurredAt, ctx.now, calendar: ctx.calendar) >= 14 }
        if let s = stale.first, due.isEmpty {
            out.append(Signal(id: ModuleHelpers.signalID(.sharedChecklist, .checklistStale, p.id), personID: p.id, moduleID: .sharedChecklist, kind: .checklistStale,
                              title: "Stuck: \(s.1.text)", body: "Open for \(CareDates.daysBetween(s.0.occurredAt, ctx.now, calendar: ctx.calendar)) days with \(p.shortName).",
                              priority: 0.2, tone: .neutral,
                              actions: [SignalAction(title: "Open list", link: .module(personID: p.id, module: .sharedChecklist), isPrimary: true)]))
        }
        return out
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let all = ctx.entries.compactMap { e -> (EntryRecord, ChecklistItemPayload)? in
            guard let item = e.decode(ChecklistItemPayload.self) else { return nil }
            return (e, item)
        }
        guard !all.isEmpty else { return nil }
        var doneBy: [String: Int] = [:]
        for (_, item) in all where item.done && (item.doneAt.map { window.contains($0) } ?? false) { doneBy[item.doneBy ?? "unknown", default: 0] += 1 }
        let stale = open(ctx).filter { CareDates.daysBetween($0.0.occurredAt, ctx.now, calendar: ctx.calendar) >= 14 }
            .map { JSONValue.string("\($0.1.text) (\(CareDates.daysBetween($0.0.occurredAt, ctx.now, calendar: ctx.calendar))d)") }
        return ContextPack(moduleID: .sharedChecklist, summary: "\(open(ctx).count) open items",
                           data: .object(["open": .int(open(ctx).count), "done_30d": .object(doneBy.mapValues { .int($0) }), "stale": .array(stale)]))
    }
}
