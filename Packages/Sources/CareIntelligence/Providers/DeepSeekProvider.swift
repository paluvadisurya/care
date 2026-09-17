import Foundation
import CareCore

/// DeepSeek's OpenAI-compatible chat completions API with JSON mode. The schema rides in the system prompt.
public struct DeepSeekProvider: LLMProvider {
    public let id: ProviderID = .deepSeek
    public var apiKey: String
    public var baseURL: URL

    public init(apiKey: String, baseURL: URL = URL(string: "https://api.deepseek.com")!) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func generateJSON(system: String, user: String, model: String, maxOutputTokens: Int, timeout: Double) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        let body: [String: JSONValue] = [
            "model": .string(model),
            "messages": .array([
                .object(["role": .string("system"), "content": .string(system)]),
                .object(["role": .string("user"), "content": .string(user + "\n\nRespond with JSON only.")]),
            ]),
            "response_format": .object(["type": .string("json_object")]),
            "max_tokens": .int(maxOutputTokens),
            "temperature": .number(0.6),
            "stream": .bool(false),
        ]
        let (data, status) = try await HTTP.postJSON(
            url: baseURL.appendingPathComponent("chat/completions"),
            headers: ["Authorization": "Bearer \(apiKey)"], body: body, timeout: timeout)
        guard (200..<300).contains(status) else {
            let tree = try? HTTP.decodeTree(data)
            throw LLMError.httpStatus(status, tree?["error"]?["message"]?.stringValue ?? String(decoding: data.prefix(160), as: UTF8.self))
        }
        let tree = try HTTP.decodeTree(data)
        return try Self.extractText(from: tree)
    }

    static func extractText(from tree: JSONValue) throws -> String {
        guard let choice = tree["choices"]?.arrayValue?.first else { throw LLMError.emptyOutput }
        if choice["finish_reason"]?.stringValue == "content_filter" { throw LLMError.refusal("content filter") }
        guard let content = choice["message"]?["content"]?.stringValue, !content.isEmpty else { throw LLMError.emptyOutput }
        return Self.stripFences(content)
    }

    /// Some models wrap JSON in ``` fences even in JSON mode.
    static func stripFences(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
