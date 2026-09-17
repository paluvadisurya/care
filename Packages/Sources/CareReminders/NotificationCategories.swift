import Foundation
import CareCore

/// One notification category per module, with the actions its module declared. Identifiers are stable strings so
/// the notification service extension can route an answer without loading module code.
public struct NotificationCategorySpec: Hashable, Sendable, Identifiable {
    public var id: String
    public var actions: [ReminderAction]

    public static func identifier(for module: ModuleID) -> String { "care.module.\(module.rawValue)" }

    public static let all: [NotificationCategorySpec] = [
        NotificationCategorySpec(id: identifier(for: .mood), actions: [ReminderAction(id: "mood.5", title: "😊 Good"), ReminderAction(id: "mood.3", title: "😐 Okay"), ReminderAction(id: "mood.1", title: "😞 Low")]),
        NotificationCategorySpec(id: identifier(for: .medication), actions: [ReminderAction(id: "taken", title: "Taken"), ReminderAction(id: "skip", title: "Skip")]),
        NotificationCategorySpec(id: identifier(for: .hydration), actions: [ReminderAction(id: "water.250", title: "+250 ml"), ReminderAction(id: "water.500", title: "+500 ml")]),
        NotificationCategorySpec(id: identifier(for: .events), actions: [ReminderAction(id: "outcome.wentWell", title: "Went well"), ReminderAction(id: "outcome.okay", title: "Okay"), ReminderAction(id: "outcome.hard", title: "Hard")]),
        NotificationCategorySpec(id: identifier(for: .callRhythm), actions: [ReminderAction(id: "call", title: "Call"), ReminderAction(id: "later", title: "Later")]),
        NotificationCategorySpec(id: identifier(for: .dates), actions: [ReminderAction(id: "plan", title: "Plan"), ReminderAction(id: "wishlist", title: "Wishlist")]),
        NotificationCategorySpec(id: identifier(for: .petCare), actions: [ReminderAction(id: "log", title: "Log it")]),
        NotificationCategorySpec(id: identifier(for: .travelPlans), actions: [ReminderAction(id: "packing", title: "Packing"), ReminderAction(id: "message", title: "Message")]),
        NotificationCategorySpec(id: identifier(for: .appointments), actions: [ReminderAction(id: "brief", title: "Open brief")]),
        NotificationCategorySpec(id: "care.standing", actions: [ReminderAction(id: "open", title: "Open"), ReminderAction(id: "skip", title: "Skip")]),
    ]

    public static func category(for reminder: PlannedReminder) -> String {
        switch reminder.kind {
        case .morningBrief, .eveningWrap: "care.standing"
        default: identifier(for: reminder.moduleID)
        }
    }
}
