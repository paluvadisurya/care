import SwiftUI
import Observation
import CareCore
import CareModules

/// Tabs, navigation paths and presented sheets. Deep links land here.
@Observable
final class AppRouter {
    enum Tab: String, CaseIterable { case today, people, timeline, you }

    enum Sheet: Identifiable {
        case addPerson
        case editPerson(UUID)
        case store(UUID?)
        case eveningWrap
        case quickLog(QuickLogRequest)

        var id: String {
            switch self {
            case .addPerson: "addPerson"
            case .editPerson(let id): "edit.\(id)"
            case .store(let id): "store.\(id?.uuidString ?? "all")"
            case .eveningWrap: "wrap"
            case .quickLog(let r): "quick.\(r.id)"
            }
        }
    }

    var tab: Tab = .today
    var todayPath: [ModuleRoute] = []
    var peoplePath: [ModuleRoute] = []
    var timelinePath: [ModuleRoute] = []
    var youPath: [ModuleRoute] = []
    var selectedPersonID: UUID?
    var timelineDay: Date = .now
    var sheet: Sheet?

    func open(_ route: ModuleRoute) {
        switch tab {
        case .today: todayPath.append(route)
        case .people: peoplePath.append(route)
        case .timeline: timelinePath.append(route)
        case .you: youPath.append(route)
        }
    }

    func handle(_ link: DeepLink) {
        switch link {
        case .today:
            tab = .today
            todayPath = []
        case .timeline(let day):
            tab = .timeline
            if let day {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "yyyy-MM-dd"
                timelineDay = f.date(from: day) ?? .now
            }
        case .you:
            tab = .you
        case .store(let personID):
            sheet = .store(personID)
        case .person(let id):
            tab = .people
            selectedPersonID = id
            peoplePath = []
        case .module(let personID, let module):
            tab = .people
            selectedPersonID = personID
            peoplePath = [ModuleRoute(personID: personID, module: module)]
        case .newEntry(let personID, let module, let title):
            sheet = .quickLog(QuickLogRequest(personID: personID, module: module, prefill: title))
        case .quickSheet(let personID):
            sheet = .quickLog(QuickLogRequest(personID: personID))
        }
    }

    /// Run a signal action. Calls and messages hand off to the system; everything else routes in-app.
    func perform(_ action: SignalAction, personPhone: String? = nil) {
        switch action.kind {
        case .call:
            if let phone = personPhone, let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                openURL(url)
            } else {
                handle(action.link)
            }
        case .message:
            if let phone = personPhone, let url = URL(string: "sms:\(phone.filter { !$0.isWhitespace })") {
                openURL(url)
            } else {
                handle(action.link)
            }
        default:
            handle(action.link)
        }
    }

    private func openURL(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#endif
