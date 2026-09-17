import Foundation
import Observation
import CareCore
import CareIntelligence

/// Runs generation for Home and people, caches through the store, and reports state to the UI.
/// Insights generate on foreground for Home and the top three people; others generate when opened.
@Observable
public final class InsightCoordinator {
    public private(set) var generating: Set<String> = []
    public private(set) var lastError: [String: String] = [:]

    private let store: CareStore
    private let prefs: AppPreferences
    private let secrets: any SecretStore

    public init(store: CareStore, prefs: AppPreferences, secrets: any SecretStore) {
        self.store = store
        self.prefs = prefs
        self.secrets = secrets
    }

    public static func key(_ scope: ScopeContext.Scope, _ id: UUID?) -> String { "\(scope.rawValue).\(id?.uuidString ?? "home")" }

    /// The engine for the current preferences: a real provider when a key exists, else the local engine.
    public func engine() -> InsightEngine {
        let config = prefs.activeModelConfig
        guard prefs.intelligenceEnabled, let key = secrets.secret(for: prefs.provider), !key.isEmpty else {
            return InsightEngine(provider: nil, config: config, validator: InsightValidator(registry: store.registry, calendar: store.calendar))
        }
        let provider: any LLMProvider = switch prefs.provider {
        case .openAI: OpenAIProvider(apiKey: key)
        case .deepSeek: DeepSeekProvider(apiKey: key)
        }
        return InsightEngine(provider: provider, config: config, validator: InsightValidator(registry: store.registry, calendar: store.calendar))
    }

    public var hasKey: Bool { secrets.secret(for: prefs.provider).map { !$0.isEmpty } ?? false }

    public func isGenerating(_ scope: ScopeContext.Scope, _ id: UUID?) -> Bool { generating.contains(Self.key(scope, id)) }

    private var builder: ContextBuilder {
        ContextBuilder(registry: store.registry, calendar: store.calendar, userName: prefs.userName.isEmpty ? (store.me?.shortName ?? "you") : prefs.userName,
                       quietHours: prefs.reminders.quietHours)
    }

    /// Generate for Home and the top three ranked people if their cache is stale.
    public func refreshOnForeground(now: Date = .now) async {
        await refreshHome(force: false, now: now)
        let ranked = store.signals(now: now)
        var seen: [UUID] = []
        for s in ranked where !seen.contains(s.personID) && seen.count < 3 { seen.append(s.personID) }
        for id in seen { if let p = store.person(id) { await refresh(person: p, force: false, now: now) } }
    }

    public func refreshHome(force: Bool, now: Date = .now) async {
        let key = Self.key(.home, nil)
        let previous = store.insight(scope: .home, scopeID: nil)
        let ctx = builder.home(people: store.people, entries: store.entries, events: store.events, signals: store.signals(now: now), now: now, previous: previous)
        await run(key: key, scope: .home, scopeID: nil, ctx: ctx, previous: previous, force: force, now: now)
    }

    public func refresh(person: PersonRecord, force: Bool, now: Date = .now) async {
        let key = Self.key(.person, person.id)
        let previous = store.insight(scope: .person, scopeID: person.id)
        let ctx = builder.person(person, entries: store.entries, events: store.events, now: now, previous: previous)
        await run(key: key, scope: .person, scopeID: person.id, ctx: ctx, previous: previous, force: force, now: now)
    }

    private func run(key: String, scope: ScopeContext.Scope, scopeID: UUID?, ctx: ScopeContext, previous: InsightRecord?, force: Bool, now: Date) async {
        let hash = builder.inputHash(ctx)
        let engine = engine()
        // With a real provider, respect the cache. The local engine is free, so always keep it fresh.
        if engine.provider != nil, !InsightEngine.shouldGenerate(existing: previous, inputHash: hash, now: now, force: force) { return }
        if engine.provider == nil, let previous, previous.inputHash == hash, previous.origin == .local, !force { return }
        guard !generating.contains(key) else { return }
        generating.insert(key)
        defer { generating.remove(key) }
        do {
            let out = try await engine.generate(ctx, now: now)
            lastError[key] = nil
            store.saveInsight(InsightRecord(scope: scope, scopeID: scopeID, generatedAt: now, expiresAt: now.addingTimeInterval(InsightEngine.cacheLifetime),
                                            modelID: out.modelID, origin: out.origin, inputHash: hash, insight: out.insight, refreshNote: out.note))
        } catch {
            lastError[key] = (error as? LLMError)?.errorDescription ?? error.localizedDescription
            if var previous {
                previous.refreshNote = "Could not refresh. Yesterday's insight is still here."
                store.saveInsight(previous)
            } else {
                // Nothing cached yet: fall back to the local engine so the card is never empty.
                let local = InsightEngine(provider: nil, config: engine.config, validator: engine.validator)
                if let out = try? await local.generate(ctx, now: now) {
                    store.saveInsight(InsightRecord(scope: scope, scopeID: scopeID, generatedAt: now, expiresAt: now.addingTimeInterval(InsightEngine.cacheLifetime),
                                                    modelID: out.modelID, origin: .local, inputHash: hash, insight: out.insight, refreshNote: "Could not reach the model. Written on device instead."))
                }
            }
        }
    }
}
