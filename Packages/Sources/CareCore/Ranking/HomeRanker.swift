import Foundation

/// Deterministic ranking of signals across everyone. The model only writes words around the top results.
///
/// Score = module priority
///       + time pressure (things due within hours climb, things days away fall)
///       + health weight (medication and health signals get a fixed boost)
///       + not-yet-acted and neglect (older unresolved signals climb slowly)
public enum HomeRanker {
    public struct Weights: Sendable {
        public var timePressure: Double = 0.35
        public var health: Double = 0.25
        public var neglect: Double = 0.15
        public init() {}
    }

    public static func rank(_ signals: [Signal], now: Date, weights: Weights = Weights()) -> [Signal] {
        signals
            .map { ($0, score($0, now: now, weights: weights)) }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.id < b.0.id
            }
            .map(\.0)
    }

    public static func score(_ s: Signal, now: Date, weights: Weights = Weights()) -> Double {
        var score = s.priority

        if let at = s.at {
            let hours = at.timeIntervalSince(now) / 3600
            if hours < 0 {
                // Overdue: strong but decaying so a week-old thing does not sit on top forever.
                score += weights.timePressure * max(0.4, 1 - min(1, -hours / 72))
            } else if hours <= 24 {
                score += weights.timePressure * (1 - hours / 24)
            } else {
                score += weights.timePressure * max(0, 0.25 - hours / (24 * 30))
            }
        }

        switch s.kind {
        case .missedDose, .readingHigh: score += weights.health
        case .doseDue, .symptomStreak, .appointmentPrep, .petCareDue: score += weights.health * 0.6
        case .lowStreak, .worryUnresolved: score += weights.health * 0.4
        default: break
        }

        switch s.kind {
        case .promiseStale, .checklistStale, .worryUnresolved, .quietWeek, .checkInDue:
            score += weights.neglect
        default: break
        }

        if s.tone == .attention { score += 0.1 }
        return score
    }

    /// The hero is the best-ranked signal with a non-plain presentation, else the top one.
    public static func hero(from ranked: [Signal]) -> Signal? {
        ranked.first { if case .plain = $0.hero { return false } else { return true } } ?? ranked.first
    }

    /// People that carry at least one attention-tone signal, for orb dots.
    public static func peopleNeedingAttention(_ signals: [Signal]) -> Set<UUID> {
        Set(signals.filter { $0.tone == .attention }.map(\.personID))
    }
}
