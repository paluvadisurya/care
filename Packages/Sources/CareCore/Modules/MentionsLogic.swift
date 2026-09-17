import Foundation

public enum MentionKind: String, Codable, CaseIterable, Sendable, Hashable {
    case want, like, dislike, fact, worry, promise

    public var label: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .want: "star"
        case .like: "heart"
        case .dislike: "hand.thumbsdown"
        case .fact: "info.circle"
        case .worry: "cloud.rain"
        case .promise: "hand.raised"
        }
    }
}

public struct MentionPayload: Codable, Hashable, Sendable {
    public var text: String
    public var kind: MentionKind
    public var resolved: Bool

    public init(text: String, kind: MentionKind? = nil, resolved: Bool = false) {
        self.text = text
        self.kind = kind ?? MentionClassifier.classify(text)
        self.resolved = resolved
    }
}

/// On-device classification. Keyword heuristics now; a Foundation Models pass can replace `classify` later.
public enum MentionClassifier {
    public static func classify(_ text: String) -> MentionKind {
        let t = text.lowercased()
        func hit(_ w: [String]) -> Bool { w.contains { t.contains($0) } }
        if hit(["worried", "worry", "scared", "anxious", "stress", "afraid", "nervous", "upset", "pain", "hurt"]) { return .worry }
        if hit(["promise", "i will", "i'll", "will get", "will book", "will call", "will bring"]) { return .promise }
        if hit(["wants", "want", "wish", "would love", "hoping for", "looking for", "needs a", "need a", "try the", "try a"]) { return .want }
        if hit(["hates", "hate", "dislike", "can't stand", "cannot stand", "not a fan", "doesn't like", "does not like"]) { return .dislike }
        if hit(["loves", "love", "likes", "like", "favourite", "favorite", "enjoys", "adores"]) { return .like }
        return .fact
    }
}

public enum MentionsLogic: ModuleLogic {
    public static let meta = ModuleCatalog.meta(.mentions)
    public static let allowedBlocks: Set<InsightBlockKind> = [.headline, .list, .talkingPoints, .action, .insight, .note]
    public static let reminderRules = [
        ReminderRule(id: "mentions.worry", kind: .signal, description: "A worry not followed up in 7 days"),
    ]

    public static func todayState(_ ctx: ModuleContext) -> ModuleTodayState {
        guard let last = ctx.entries.first, let p = last.decode(MentionPayload.self) else {
            return ModuleTodayState(headline: "Nothing noted", detail: "Hold to talk")
        }
        let count = ctx.entries.count
        return ModuleTodayState(headline: p.text, detail: "\(ModuleHelpers.plural(count, "note")) · \(p.kind.label.lowercased())")
    }

    public static func signals(_ ctx: ModuleContext) -> [Signal] {
        let p = ctx.person
        let worries = ctx.entries.filter {
            guard let m = $0.decode(MentionPayload.self) else { return false }
            return m.kind == .worry && !m.resolved && CareDates.daysBetween($0.occurredAt, ctx.now, calendar: ctx.calendar) >= 7
        }
        guard let w = worries.first, let m = w.decode(MentionPayload.self) else { return [] }
        return [Signal(
            id: ModuleHelpers.signalID(.mentions, .worryUnresolved, p.id), personID: p.id, moduleID: .mentions, kind: .worryUnresolved,
            title: "\(p.shortName) mentioned a worry", body: "\"\(m.text)\" \(CareDates.relativeDays(from: ctx.now, to: w.occurredAt)). Ask how it went.",
            at: w.occurredAt, priority: 0.4, tone: .upcoming,
            actions: [SignalAction(title: "Ask about it", kind: .message, link: .module(personID: p.id, module: .mentions), isPrimary: true)])]
    }

    public static func contextPack(_ ctx: ModuleContext, window: DateInterval) -> ContextPack? {
        let entries = ctx.entries(in: window).prefix(20)
        guard !entries.isEmpty else { return nil }
        let rows = entries.compactMap { e -> JSONValue? in
            guard let m = e.decode(MentionPayload.self) else { return nil }
            return .object(["id": .string(e.id.uuidString), "t": .string(String(m.text.prefix(140))), "type": .string(m.kind.rawValue),
                            "d": .string(CareDates.shortDay(e.occurredAt)), "resolved": .bool(m.resolved)])
        }
        return ContextPack(moduleID: .mentions, summary: "\(rows.count) mentions", data: .array(rows),
                           evidenceIDs: entries.map { $0.id.uuidString })
    }

    /// Talking points for a call: open wants and worries, newest first.
    public static func talkingPoints(from entries: [EntryRecord], limit: Int = 3) -> [String] {
        entries.filter { $0.moduleID == .mentions }
            .sorted { $0.occurredAt > $1.occurredAt }
            .compactMap { $0.decode(MentionPayload.self) }
            .filter { !$0.resolved && ($0.kind == .want || $0.kind == .worry || $0.kind == .fact) }
            .prefix(limit).map { $0.text }
    }
}
