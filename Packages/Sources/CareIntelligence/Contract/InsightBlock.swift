import Foundation
import CareCore

public enum StatTone: String, Codable, Sendable, Hashable { case good, neutral, attention }
public enum TrendDirection: String, Codable, Sendable, Hashable { case up, down, flat }

public struct ListItem: Codable, Hashable, Sendable {
    public var text: String
    public var entryID: String?
    public init(text: String, entryID: String? = nil) {
        self.text = text
        self.entryID = entryID
    }
    enum CodingKeys: String, CodingKey { case text, entryID = "entry_id" }
}

/// The eleven block types the model may return. Unknown types decode to `.unknown` and are dropped by the validator.
public enum InsightBlock: Hashable, Sendable, Identifiable {
    case stat(label: String, value: String, trend: TrendDirection?, tone: StatTone)
    case trend(label: String, points: [Double], annotation: String?)
    case countdown(title: String, date: String)
    case list(title: String, items: [ListItem])
    case action(title: String, reason: String, deeplink: String)
    case insight(text: String, evidenceIDs: [String])
    case moodStrip(label: String, values: [Int?])
    case talkingPoints(items: [String])
    case compare(label: String, aLabel: String, a: Double, bLabel: String, b: Double)
    case note(text: String)
    case unknown(type: String)

    public var kind: InsightBlockKind? {
        switch self {
        case .stat: .stat
        case .trend: .trend
        case .countdown: .countdown
        case .list: .list
        case .action: .action
        case .insight: .insight
        case .moodStrip: .moodStrip
        case .talkingPoints: .talkingPoints
        case .compare: .compare
        case .note: .note
        case .unknown: nil
        }
    }

    public var id: String {
        switch self {
        case .stat(let l, let v, _, _): "stat.\(l).\(v)"
        case .trend(let l, _, _): "trend.\(l)"
        case .countdown(let t, let d): "countdown.\(t).\(d)"
        case .list(let t, _): "list.\(t)"
        case .action(let t, _, _): "action.\(t)"
        case .insight(let t, _): "insight.\(t.prefix(24))"
        case .moodStrip(let l, _): "mood.\(l)"
        case .talkingPoints(let items): "talk.\(items.first ?? "")"
        case .compare(let l, _, _, _, _): "compare.\(l)"
        case .note(let t): "note.\(t.prefix(24))"
        case .unknown(let t): "unknown.\(t)"
        }
    }

    /// Every text the block shows, for the safety filter.
    public var allText: [String] {
        switch self {
        case .stat(let l, let v, _, _): [l, v]
        case .trend(let l, _, let a): [l, a ?? ""]
        case .countdown(let t, _): [t]
        case .list(let t, let items): [t] + items.map(\.text)
        case .action(let t, let r, _): [t, r]
        case .insight(let t, _): [t]
        case .moodStrip(let l, _): [l]
        case .talkingPoints(let items): items
        case .compare(let l, let a, _, let b, _): [l, a, b]
        case .note(let t): [t]
        case .unknown: []
        }
    }
}

extension InsightBlock: Codable {
    private enum Keys: String, CodingKey {
        case type, label, value, trend, tone, points, annotation, title, date, items, reason, deeplink, text
        case evidenceIDs = "evidence_ids", values, aLabel = "a_label", a, bLabel = "b_label", b
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "stat":
            self = .stat(label: try c.decode(String.self, forKey: .label), value: try c.decode(String.self, forKey: .value),
                         trend: try c.decodeIfPresent(TrendDirection.self, forKey: .trend),
                         tone: try c.decodeIfPresent(StatTone.self, forKey: .tone) ?? .neutral)
        case "trend":
            self = .trend(label: try c.decode(String.self, forKey: .label), points: try c.decodeIfPresent([Double].self, forKey: .points) ?? [],
                          annotation: try c.decodeIfPresent(String.self, forKey: .annotation))
        case "countdown":
            self = .countdown(title: try c.decode(String.self, forKey: .title), date: try c.decode(String.self, forKey: .date))
        case "list":
            let raw = try c.decodeIfPresent([ListItem].self, forKey: .items) ?? []
            self = .list(title: try c.decode(String.self, forKey: .title), items: raw)
        case "action":
            self = .action(title: try c.decode(String.self, forKey: .title), reason: try c.decodeIfPresent(String.self, forKey: .reason) ?? "",
                           deeplink: try c.decode(String.self, forKey: .deeplink))
        case "insight":
            self = .insight(text: try c.decode(String.self, forKey: .text), evidenceIDs: try c.decodeIfPresent([String].self, forKey: .evidenceIDs) ?? [])
        case "mood_strip":
            self = .moodStrip(label: try c.decodeIfPresent(String.self, forKey: .label) ?? "Mood", values: try c.decodeIfPresent([Int?].self, forKey: .values) ?? [])
        case "talking_points":
            self = .talkingPoints(items: try c.decodeIfPresent([String].self, forKey: .items) ?? [])
        case "compare":
            self = .compare(label: try c.decode(String.self, forKey: .label), aLabel: try c.decode(String.self, forKey: .aLabel), a: try c.decode(Double.self, forKey: .a),
                            bLabel: try c.decode(String.self, forKey: .bLabel), b: try c.decode(Double.self, forKey: .b))
        case "note":
            self = .note(text: try c.decode(String.self, forKey: .text))
        default:
            self = .unknown(type: type)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .stat(let label, let value, let trend, let tone):
            try c.encode("stat", forKey: .type); try c.encode(label, forKey: .label); try c.encode(value, forKey: .value)
            try c.encode(trend, forKey: .trend); try c.encode(tone, forKey: .tone)
        case .trend(let label, let points, let annotation):
            try c.encode("trend", forKey: .type); try c.encode(label, forKey: .label); try c.encode(points, forKey: .points); try c.encode(annotation, forKey: .annotation)
        case .countdown(let title, let date):
            try c.encode("countdown", forKey: .type); try c.encode(title, forKey: .title); try c.encode(date, forKey: .date)
        case .list(let title, let items):
            try c.encode("list", forKey: .type); try c.encode(title, forKey: .title); try c.encode(items, forKey: .items)
        case .action(let title, let reason, let deeplink):
            try c.encode("action", forKey: .type); try c.encode(title, forKey: .title); try c.encode(reason, forKey: .reason); try c.encode(deeplink, forKey: .deeplink)
        case .insight(let text, let evidenceIDs):
            try c.encode("insight", forKey: .type); try c.encode(text, forKey: .text); try c.encode(evidenceIDs, forKey: .evidenceIDs)
        case .moodStrip(let label, let values):
            try c.encode("mood_strip", forKey: .type); try c.encode(label, forKey: .label); try c.encode(values, forKey: .values)
        case .talkingPoints(let items):
            try c.encode("talking_points", forKey: .type); try c.encode(items, forKey: .items)
        case .compare(let label, let aLabel, let a, let bLabel, let b):
            try c.encode("compare", forKey: .type); try c.encode(label, forKey: .label); try c.encode(aLabel, forKey: .aLabel); try c.encode(a, forKey: .a)
            try c.encode(bLabel, forKey: .bLabel); try c.encode(b, forKey: .b)
        case .note(let text):
            try c.encode("note", forKey: .type); try c.encode(text, forKey: .text)
        case .unknown(let type):
            try c.encode(type, forKey: .type)
        }
    }
}
