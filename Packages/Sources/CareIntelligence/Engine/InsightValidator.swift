import Foundation
import CareCore

/// Rejects or trims model output before anything renders. The app always has the final say.
public struct InsightValidator: Sendable {
    public struct Rules: Sendable {
        public var maxBlocks = 7
        public var maxHeadline = 80
        public var maxActions = 1
        public var maxReminders = 3
        public var quietHours = ["22:00", "07:00"]
        /// Clinical terms the model must never use. Matching is case-insensitive, whole words.
        public var blockedTerms = [
            "diagnos", "hypertension", "diabetes", "diabetic", "depression", "depressed", "anxiety disorder",
            "bipolar", "cancer", "tumor", "tumour", "stroke", "heart attack", "prescribe", "dosage increase",
            "arrhythmia", "infection", "disorder", "syndrome",
        ]
        public init() {}
    }

    public var rules: Rules
    public var registry: ModuleRegistry
    public var calendar: Calendar

    public init(rules: Rules = Rules(), registry: ModuleRegistry = .standard, calendar: Calendar = .care) {
        self.rules = rules
        self.registry = registry
        self.calendar = calendar
    }

    public struct Result: Sendable {
        public var insight: Insight
        public var dropped: [String]
        public var isUsable: Bool { !insight.headline.isEmpty }
    }

    public func validate(_ raw: Insight, context: ScopeContext, now: Date) -> Result {
        var dropped: [String] = []
        var out = raw
        out.headline = clean(String(raw.headline.prefix(rules.maxHeadline)))
        if containsBlockedTerm(out.headline) {
            dropped.append("headline: clinical term")
            out.headline = fallbackHeadline(context)
        }

        var blocks: [InsightBlock] = []
        var actions = 0
        for block in raw.blocks {
            guard let kind = block.kind else { dropped.append("unknown block"); continue }
            guard context.allowedBlocks.contains(kind) else { dropped.append("\(kind.rawValue): not allowed"); continue }
            if block.allText.contains(where: containsBlockedTerm) { dropped.append("\(kind.rawValue): clinical term"); continue }
            if case .action(_, _, let link) = block {
                actions += 1
                guard actions <= rules.maxActions else { dropped.append("action: cap"); continue }
                guard let deepLink = DeepLink(string: link) else { dropped.append("action: bad deeplink"); continue }
                if let m = deepLink.module, !context.allowedModules.contains(m) { dropped.append("action: module not allowed"); continue }
                if let m = deepLink.module, !registry.isImplemented(m) { dropped.append("action: module unknown"); continue }
            }
            if case .moodStrip(_, let values) = block, values.contains(where: { ($0 ?? 3) < 1 || ($0 ?? 3) > 5 }) {
                dropped.append("mood_strip: out of range"); continue
            }
            blocks.append(cleaned(block))
        }
        // Notes always last, at most one.
        let notes = blocks.filter { if case .note = $0 { return true } else { return false } }
        blocks.removeAll { if case .note = $0 { return true } else { return false } }
        blocks = Array(blocks.prefix(rules.maxBlocks - 1))
        if let note = notes.first { blocks.append(note) }
        out.blocks = blocks

        let limit = CareDates.adding(days: 7, to: now, calendar: calendar)
        out.reminders = raw.reminders.prefix(rules.maxReminders).filter { r in
            guard let date = Self.parseLocal(r.fireAt, calendar: calendar) else { dropped.append("reminder: bad time"); return false }
            guard date > now, date <= limit else { dropped.append("reminder: outside 7 days"); return false }
            guard !CareDates.isQuiet(date, quietHours: rules.quietHours, calendar: calendar) else { dropped.append("reminder: quiet hours"); return false }
            guard !containsBlockedTerm(r.message) else { dropped.append("reminder: clinical term"); return false }
            return true
        }
        out.evidence = Array(raw.evidence.prefix(6))
        return Result(insight: out, dropped: dropped)
    }

    public func containsBlockedTerm(_ text: String) -> Bool {
        let t = text.lowercased()
        return rules.blockedTerms.contains { t.contains($0) }
    }

    private func clean(_ s: String) -> String {
        s.replacingOccurrences(of: " — ", with: ". ").replacingOccurrences(of: "—", with: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleaned(_ block: InsightBlock) -> InsightBlock {
        switch block {
        case .insight(let text, let ids): .insight(text: clean(String(text.prefix(280))), evidenceIDs: ids)
        case .note(let text): .note(text: clean(String(text.prefix(160))))
        case .list(let title, let items): .list(title: clean(title), items: Array(items.prefix(5)).map { ListItem(text: clean($0.text), entryID: $0.entryID) })
        case .talkingPoints(let items): .talkingPoints(items: Array(items.prefix(3)).map(clean))
        case .trend(let label, let points, let annotation): .trend(label: clean(label), points: Array(points.prefix(30)), annotation: annotation.map(clean))
        case .moodStrip(let label, let values): .moodStrip(label: clean(label), values: Array(values.suffix(14)))
        default: block
        }
    }

    private func fallbackHeadline(_ ctx: ScopeContext) -> String {
        if let p = ctx.person { return "A quiet look at \(p.name)'s week" }
        return "Here is how everyone is doing"
    }

    static func parseLocal(_ s: String, calendar: Calendar) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
