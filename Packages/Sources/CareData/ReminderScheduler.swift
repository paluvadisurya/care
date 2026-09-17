import Foundation
import CareCore
import CareReminders
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Plans nightly-style and schedules through UserNotifications. Categories carry the module's actions so an
/// answer never needs the app to open.
public final class ReminderScheduler {
    public init() {}

    #if canImport(UserNotifications)
    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func registerCategories() {
        let categories = Set(NotificationCategorySpec.all.map { spec in
            UNNotificationCategory(identifier: spec.id, actions: spec.actions.map {
                UNNotificationAction(identifier: $0.id, title: $0.title, options: [])
            }, intentIdentifiers: [], options: [])
        })
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    /// Replaces every pending Care reminder with the new plan.
    public func schedule(_ plan: [PlannedReminder], calendar: Calendar = .care) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("care.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for r in plan where r.fireAt > .now {
            let content = UNMutableNotificationContent()
            content.title = r.personName
            content.body = r.message
            content.sound = .default
            content.categoryIdentifier = NotificationCategorySpec.category(for: r)
            content.userInfo = ["reminderId": r.id, "deeplink": r.link.url.absoluteString, "personID": r.personID.uuidString, "module": r.moduleID.rawValue]
            content.interruptionLevel = r.interruption == .timeSensitive ? .timeSensitive : .active
            content.threadIdentifier = r.personID.uuidString
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: r.fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "care." + r.id, content: content, trigger: trigger))
        }
    }

    public func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().filter { $0.identifier.hasPrefix("care.") }.count
    }
    #endif
}
