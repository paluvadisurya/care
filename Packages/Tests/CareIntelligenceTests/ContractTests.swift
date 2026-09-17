import Testing
import Foundation
@testable import CareIntelligence
import CareCore
import CareFixtures

@Suite("Insight contract")
struct ContractTests {
    @Test("The sample answer decodes into typed blocks")
    func decodeSample() throws {
        let insight = try PayloadCoder.decoder.decode(Insight.self, from: Data(MockProvider.sample.utf8))
        #expect(insight.blocks.count == 6)
        #expect(insight.blocks.compactMap(\.kind).contains(.moodStrip))
        #expect(insight.action != nil)
    }

    @Test("Unknown block types decode to .unknown and are dropped by the validator")
    func unknownBlocks() throws {
        let json = """
        {"scope":"person","tone":"neutral","headline":"Hi","blocks":[{"type":"hologram","x":1},{"type":"note","text":"ok"}],"reminders":[],"evidence":[]}
        """
        let insight = try PayloadCoder.decoder.decode(Insight.self, from: Data(json.utf8))
        #expect(insight.blocks.count == 2)
        let fixture = DemoCircle.make()
        let ctx = ContextBuilder(userName: "Surya").person(fixture.people[1], entries: fixture.entries, events: fixture.events, now: fixture.now)
        let result = InsightValidator().validate(insight, context: ctx, now: fixture.now)
        #expect(result.insight.blocks.count == 1)
        #expect(result.dropped.contains("unknown block"))
    }

    @Test("Blocks round-trip through encode and decode")
    func roundTrip() throws {
        let original = Insight(scope: .person, tone: .positive, headline: "Test", blocks: [
            .stat(label: "A", value: "1", trend: .up, tone: .good),
            .compare(label: "L", aLabel: "x", a: 1, bLabel: "y", b: 2),
            .talkingPoints(items: ["one", "two"]),
        ])
        let data = try PayloadCoder.encode(original)
        let back = try PayloadCoder.decode(Insight.self, from: data)
        #expect(back == original)
    }

    @Test("Schema parses and names every block kind")
    func schema() {
        #expect(InsightSchema.coversEveryBlockKind)
    }
}

@Suite("Validator")
struct ValidatorTests {
    let fixture = DemoCircle.make()

    func context() -> ScopeContext {
        ContextBuilder(userName: "Surya").person(fixture.people[1], entries: fixture.entries, events: fixture.events, now: fixture.now)
    }

    @Test("Clinical terms are dropped")
    func blockedTerms() {
        let insight = Insight(scope: .person, tone: .neutral, headline: "Signs of hypertension", blocks: [.note(text: "This looks like diabetes")])
        let result = InsightValidator().validate(insight, context: context(), now: fixture.now)
        #expect(!result.insight.headline.lowercased().contains("hypertension"))
        #expect(result.insight.blocks.isEmpty)
    }

    @Test("Only one action survives and its module must be allowed")
    func actions() {
        let pid = fixture.people[1].id
        let insight = Insight(scope: .person, tone: .neutral, headline: "ok", blocks: [
            .action(title: "a", reason: "", deeplink: DeepLink.module(personID: pid, module: .dates).url.absoluteString),
            .action(title: "b", reason: "", deeplink: DeepLink.module(personID: pid, module: .dates).url.absoluteString),
            .action(title: "c", reason: "", deeplink: DeepLink.module(personID: pid, module: .school).url.absoluteString),
        ])
        let result = InsightValidator().validate(insight, context: context(), now: fixture.now)
        #expect(result.insight.blocks.count == 1)
    }

    @Test("Reminders inside quiet hours or beyond seven days are rejected")
    func reminders() {
        let cal = fixture.calendar
        let quiet = CareDates.at(hour: 23, on: CareDates.adding(days: 1, to: fixture.now, calendar: cal), calendar: cal)
        let far = CareDates.adding(days: 20, to: fixture.now, calendar: cal)
        let fine = CareDates.at(hour: 10, on: CareDates.adding(days: 2, to: fixture.now, calendar: cal), calendar: cal)
        let f = ISO8601DateFormatter()
        let insight = Insight(scope: .person, tone: .neutral, headline: "ok", blocks: [.note(text: "n")], reminders: [
            ProposedReminder(fireAt: f.string(from: quiet), message: "a", reason: "", module: "mood", personID: ""),
            ProposedReminder(fireAt: f.string(from: far), message: "b", reason: "", module: "mood", personID: ""),
            ProposedReminder(fireAt: f.string(from: fine), message: "c", reason: "", module: "mood", personID: ""),
        ])
        let result = InsightValidator(calendar: cal).validate(insight, context: context(), now: fixture.now)
        #expect(result.insight.reminders.count == 1)
        #expect(result.insight.reminders.first?.message == "c")
    }
}

@Suite("Engine")
struct EngineTests {
    let fixture = DemoCircle.make()

    @Test("Without a provider the local engine writes an insight for every person")
    func localForEveryone() async throws {
        let engine = InsightEngine(provider: nil, config: .default(for: .openAI))
        for person in fixture.people where person.relationship != .me {
            let ctx = ContextBuilder(userName: "Surya").person(person, entries: fixture.entries, events: fixture.events, now: fixture.now)
            let out = try await engine.generate(ctx, now: fixture.now)
            #expect(out.origin == .local)
            #expect(!out.insight.headline.isEmpty)
            #expect(!out.insight.blocks.isEmpty)
        }
    }

    @Test("A malformed model answer throws and never crashes")
    func malformed() async {
        let engine = InsightEngine(provider: MockProvider(response: "not json"), config: .default(for: .openAI))
        let ctx = ContextBuilder(userName: "Surya").person(fixture.people[1], entries: fixture.entries, events: fixture.events, now: fixture.now)
        await #expect(throws: LLMError.self) { try await engine.generate(ctx, now: fixture.now) }
    }

    @Test("A valid model answer is rendered as model origin")
    func modelPath() async throws {
        let engine = InsightEngine(provider: MockProvider(), config: .default(for: .openAI))
        let ctx = ContextBuilder(userName: "Surya").person(fixture.people[1], entries: fixture.entries, events: fixture.events, now: fixture.now)
        let out = try await engine.generate(ctx, now: fixture.now)
        #expect(out.origin == .model)
        #expect(out.insight.headline == "A good month with a Wednesday dip")
    }

    @Test("Cache skips the call when the hash is unchanged")
    func cachePolicy() {
        let rec = InsightRecord(scope: .person, scopeID: nil, generatedAt: fixture.now.addingTimeInterval(-3 * 86400), expiresAt: fixture.now.addingTimeInterval(-2 * 86400),
                                modelID: "m", origin: .model, inputHash: "abc", insight: Insight(scope: .person, tone: .neutral, headline: "h", blocks: []))
        #expect(!InsightEngine.shouldGenerate(existing: rec, inputHash: "abc", now: fixture.now, force: false))
        #expect(InsightEngine.shouldGenerate(existing: rec, inputHash: "def", now: fixture.now, force: false))
        #expect(InsightEngine.shouldGenerate(existing: rec, inputHash: "abc", now: fixture.now, force: true))
    }

    @Test("DeepSeek fences are stripped")
    func fences() {
        #expect(DeepSeekProvider.stripFences("```json\n{\"a\":1}\n```") == "{\"a\":1}")
    }
}
