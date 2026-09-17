import Foundation
import CareCore

/// The system voice and the per-scope user messages. The system prompt is stable so it caches well.
public enum PromptLibrary {
    public static let system = """
    You write insights for Care, an app that helps one person look after the people in their life.
    You receive compact JSON about ONE scope (a person, a module, or the whole home) and must answer
    ONLY with the care_insight JSON contract. No prose outside the JSON.
    Voice: warm, specific, short. Like a thoughtful friend who noticed something. Never clinical.
    Rules:
    1. Be specific. Name days, counts, tags. Never vague encouragement.
    2. Never diagnose, never name a condition, never give medical advice. If health data suggests
       a doctor might help, say exactly that in a "note" block and nothing more.
    3. Never blame the user or the person. No "you should have".
    4. If there is not enough data, say so in the headline and return at most one "note" block.
    5. Use at most one "action". It must be something the user can do this week, and the deeplink
       must use only modules listed in allowed_modules.
    6. "reminders" are optional and at most 3. Only propose a reminder when there is a clear reason.
       fire_at must be outside quiet_hours and within the next 7 days.
    7. Every claim must be traceable: add the ids you used to evidence_ids, and summarize what you
       read in "evidence" (for example "21 check-ins, 6 mentions").
    8. Respect visibility: data marked private_to_user is for the user's eyes; never phrase it as if
       the person said it.
    9. Plain English. No em dashes. Sentence case. Under 80 characters for headline. At most 7 blocks.
       The last block is always a "note" with the evidence line and, for health data, "Not medical advice."
    10. Pets are family too: for a pet, write about care tasks, never about mood.
    """

    /// DeepSeek has no strict schema mode, so the schema rides along in the system prompt.
    public static var systemWithSchema: String {
        system + "\n\nAnswer with a single JSON object that validates against this JSON schema:\n" + InsightSchema.json
    }

    /// Wire shape of the user message. Snake case keys as in the spec.
    struct UserMessage: Encodable {
        struct User: Encodable { var name: String; var timezone: String; var quiet_hours: [String] }
        struct Person: Encodable { var id: String; var name: String; var relationship: String; var aura: String }
        struct Window: Encodable { var from: String; var to: String }
        var scope: String
        var today: String
        var user: User
        var person: Person?
        var people: [Person]?
        var allowed_modules: [String]
        var allowed_blocks: [String]
        var window: Window
        var packs: [String: JSONValue]
        var previous_headline: String?
        var previous_feedback: String?
    }

    public static func userMessage(for ctx: ScopeContext) -> String {
        func person(_ p: PersonBrief) -> UserMessage.Person {
            UserMessage.Person(id: p.id, name: p.name, relationship: p.relationship.rawValue, aura: p.aura)
        }
        var packs: [String: JSONValue] = [:]
        for pack in ctx.packs {
            var obj: [String: JSONValue] = ["summary": .string(pack.summary), "data": pack.data]
            if pack.privateToUser { obj["private_to_user"] = .bool(true) }
            packs[pack.moduleID.rawValue] = .object(obj)
        }
        let message = UserMessage(
            scope: ctx.scope.rawValue, today: ctx.today,
            user: .init(name: ctx.userName, timezone: ctx.timeZone, quiet_hours: ctx.quietHours),
            person: ctx.person.map(person), people: ctx.scope == .home || ctx.scope == .weekly ? ctx.people.map(person) : nil,
            allowed_modules: ctx.allowedModules.map(\.rawValue), allowed_blocks: ctx.allowedBlocks.map(\.rawValue),
            window: .init(from: ctx.windowFrom, to: ctx.windowTo), packs: packs,
            previous_headline: ctx.previousHeadline, previous_feedback: ctx.previousFeedback?.rawValue)
        let data = (try? PayloadCoder.encode(message)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
