import Foundation
import CareCore

/// Orchestrates one generation: prompt, provider, decode, validate. Falls back to the local engine when there is
/// no provider, and reports what happened so the UI can say "written on device" or "could not refresh".
public struct InsightEngine: Sendable {
    public struct Output: Sendable {
        public var insight: Insight
        public var origin: InsightOrigin
        public var modelID: String
        public var dropped: [String]
        public var note: String?
    }

    public var provider: (any LLMProvider)?
    public var config: ModelConfig
    public var validator: InsightValidator
    public var local: LocalInsightEngine

    public init(provider: (any LLMProvider)?, config: ModelConfig, validator: InsightValidator = InsightValidator(), local: LocalInsightEngine = LocalInsightEngine()) {
        self.provider = provider
        self.config = config
        self.validator = validator
        self.local = local
    }

    /// Generates for a context. Never throws for the local path; throws `LLMError` when a provider fails so the
    /// caller can decide whether to keep yesterday's insight.
    public func generate(_ ctx: ScopeContext, now: Date = .now) async throws -> Output {
        guard let provider else {
            let insight = validator.validate(local.generate(ctx), context: ctx, now: now)
            return Output(insight: insight.insight, origin: .local, modelID: "on-device rules", dropped: insight.dropped, note: nil)
        }
        let model = ctx.scope == .weekly ? config.weeklyModel : config.dailyModel
        let system = provider.id == .openAI ? PromptLibrary.system : PromptLibrary.systemWithSchema
        let text = try await provider.generateJSON(system: system, user: PromptLibrary.userMessage(for: ctx), model: model,
                                                   maxOutputTokens: config.maxOutputTokens, timeout: config.timeoutSeconds)
        let raw: Insight
        do {
            raw = try PayloadCoder.decoder.decode(Insight.self, from: Data(text.utf8))
        } catch {
            throw LLMError.malformed(text)
        }
        let result = validator.validate(raw, context: ctx, now: now)
        guard result.isUsable, !result.insight.blocks.isEmpty else {
            // The model answered but nothing survived validation. Use the local engine rather than an empty card.
            let fallback = validator.validate(local.generate(ctx), context: ctx, now: now)
            return Output(insight: fallback.insight, origin: .local, modelID: model, dropped: result.dropped, note: "Model answer was dropped by the validator.")
        }
        return Output(insight: result.insight, origin: .model, modelID: model, dropped: result.dropped, note: nil)
    }

    /// Cache policy: 24 hours, and skip the call entirely when the input hash has not changed.
    public static let cacheLifetime: TimeInterval = 24 * 3600
    public static let manualRefreshCooldown: TimeInterval = 3600

    public static func shouldGenerate(existing: InsightRecord?, inputHash: String, now: Date, force: Bool) -> Bool {
        guard let existing else { return true }
        if force { return now.timeIntervalSince(existing.generatedAt) >= manualRefreshCooldown || existing.origin == .local }
        if existing.inputHash == inputHash { return false }
        return existing.isExpired(at: now)
    }
}
