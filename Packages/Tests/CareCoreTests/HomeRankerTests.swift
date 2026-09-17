import Testing
import Foundation
@testable import CareCore

@Suite("HomeRanker")
struct HomeRankerTests {
    let now = Date(timeIntervalSince1970: 1_789_000_000)
    let person = UUID()

    func signal(_ kind: SignalKind, priority: Double, at: Date? = nil, tone: Tone = .neutral) -> Signal {
        Signal(id: "\(kind.rawValue)", personID: person, moduleID: .mood, kind: kind, title: "", body: "", at: at, priority: priority, tone: tone)
    }

    @Test("A missed dose outranks a date twelve days away")
    func missedDoseWins() {
        let dose = signal(.missedDose, priority: 0.8, at: now.addingTimeInterval(-3600), tone: .attention)
        let date = signal(.dateSoon, priority: 0.5, at: now.addingTimeInterval(12 * 86400), tone: .upcoming)
        let ranked = HomeRanker.rank([date, dose], now: now)
        #expect(ranked.first?.kind == .missedDose)
    }

    @Test("Time pressure lifts something due in an hour above something due tomorrow")
    func timePressure() {
        let soon = signal(.eventSoon, priority: 0.5, at: now.addingTimeInterval(3600))
        let later = signal(.eventSoon, priority: 0.5, at: now.addingTimeInterval(30 * 3600))
        #expect(HomeRanker.score(soon, now: now) > HomeRanker.score(later, now: now))
    }

    @Test("Ranking is deterministic for equal scores")
    func deterministic() {
        let a = Signal(id: "a", personID: person, moduleID: .mood, kind: .checkInDue, title: "", body: "", priority: 0.3)
        let b = Signal(id: "b", personID: person, moduleID: .mood, kind: .checkInDue, title: "", body: "", priority: 0.3)
        #expect(HomeRanker.rank([b, a], now: now).map(\.id) == ["a", "b"])
    }

    @Test("Hero prefers a signal with a presentation")
    func heroPick() {
        let plain = signal(.checkInDue, priority: 0.9)
        var countdown = signal(.dateSoon, priority: 0.5, at: now.addingTimeInterval(86400))
        countdown.hero = .countdown(now.addingTimeInterval(86400))
        let ranked = HomeRanker.rank([plain, countdown], now: now)
        #expect(ranked.first?.kind == .checkInDue)
        #expect(HomeRanker.hero(from: ranked)?.kind == .dateSoon)
    }
}
