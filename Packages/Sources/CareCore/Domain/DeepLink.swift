import Foundation

/// care:// links used by widgets, notifications and insight actions.
public enum DeepLink: Hashable, Sendable, Codable {
    case today
    case timeline(day: String?)
    case you
    case store(personID: UUID?)
    case person(UUID)
    case module(personID: UUID, module: ModuleID)
    case newEntry(personID: UUID, module: ModuleID, title: String?)
    case quickSheet(personID: UUID)

    public static let scheme = "care"

    public var url: URL {
        var c = URLComponents()
        c.scheme = DeepLink.scheme
        switch self {
        case .today:
            c.host = "today"
        case .timeline(let day):
            c.host = "timeline"
            if let day { c.path = "/\(day)" }
        case .you:
            c.host = "you"
        case .store(let personID):
            c.host = "store"
            if let personID { c.path = "/\(personID.uuidString)" }
        case .person(let id):
            c.host = "person"
            c.path = "/\(id.uuidString)"
        case .module(let personID, let module):
            c.host = "person"
            c.path = "/\(personID.uuidString)/\(module.rawValue)"
        case .newEntry(let personID, let module, let title):
            c.host = "person"
            c.path = "/\(personID.uuidString)/\(module.rawValue)/new"
            if let title { c.queryItems = [URLQueryItem(name: "title", value: title)] }
        case .quickSheet(let personID):
            c.host = "person"
            c.path = "/\(personID.uuidString)/quick"
        }
        return c.url ?? URL(string: "care://today")!
    }

    public init?(url: URL) {
        guard url.scheme == DeepLink.scheme, let host = url.host else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "today": self = .today
        case "you": self = .you
        case "timeline": self = .timeline(day: parts.first)
        case "store": self = .store(personID: parts.first.flatMap(UUID.init(uuidString:)))
        case "person":
            guard let idString = parts.first, let id = UUID(uuidString: idString) else { return nil }
            if parts.count == 1 { self = .person(id); return }
            if parts[1] == "quick" { self = .quickSheet(personID: id); return }
            guard let module = ModuleID(rawValue: parts[1]) else { return nil }
            if parts.count >= 3, parts[2] == "new" {
                let title = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "title" }?.value
                self = .newEntry(personID: id, module: module, title: title)
            } else {
                self = .module(personID: id, module: module)
            }
        default: return nil
        }
    }

    public init?(string: String) {
        guard let url = URL(string: string) else { return nil }
        self.init(url: url)
    }

    /// The module this link targets, if any. Used by the validator.
    public var module: ModuleID? {
        switch self {
        case .module(_, let m), .newEntry(_, let m, _): m
        default: nil
        }
    }

    public var personID: UUID? {
        switch self {
        case .person(let id), .module(let id, _), .newEntry(let id, _, _), .quickSheet(let id): id
        case .store(let id): id
        default: nil
        }
    }
}
