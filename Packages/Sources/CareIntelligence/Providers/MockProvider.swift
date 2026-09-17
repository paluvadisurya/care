import Foundation
import CareCore

/// Returns canned JSON. Used by previews, tests and the demo profile.
public struct MockProvider: LLMProvider {
    public let id: ProviderID
    public var response: String
    public var delay: Duration
    public var error: LLMError?

    public init(id: ProviderID = .openAI, response: String = MockProvider.sample, delay: Duration = .zero, error: LLMError? = nil) {
        self.id = id
        self.response = response
        self.delay = delay
        self.error = error
    }

    public func generateJSON(system: String, user: String, model: String, maxOutputTokens: Int, timeout: Double) async throws -> String {
        if delay > .zero { try await Task.sleep(for: delay) }
        if let error { throw error }
        return response
    }

    public static let sample = """
    {
      "scope": "person", "tone": "positive",
      "headline": "A good month with a Wednesday dip",
      "blocks": [
        {"type":"stat","label":"Check-ins","value":"21","trend":"up","tone":"good"},
        {"type":"stat","label":"Good or better","value":"71%","trend":"up","tone":"good"},
        {"type":"mood_strip","label":"Mood, 14 days","values":[4,4,3,2,4,5,4,4,3,2,4,4,5,4]},
        {"type":"list","title":"Things she mentioned","items":[{"text":"Pottery class (2x)","entry_id":null},{"text":"Weekend in the hills","entry_id":null}]},
        {"type":"action","title":"Plan a midweek dinner","reason":"Adds an event on Wed 7pm","deeplink":"care://person/00000000-0000-0000-0000-000000000000/events/new?title=Dinner"},
        {"type":"note","text":"Based on 21 check-ins, 6 mentions, 2 events. Not medical advice."}
      ],
      "reminders": [],
      "evidence": ["21 check-ins", "6 mentions", "2 events"]
    }
    """
}
