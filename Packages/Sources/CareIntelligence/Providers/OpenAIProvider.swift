import Foundation
import CareCore

/// OpenAI Responses API with strict structured output.
public struct OpenAIProvider: LLMProvider {
    public let id: ProviderID = .openAI
    public var apiKey: String
    public var baseURL: URL

    public init(apiKey: String, baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func generateJSON(system: String, user: String, model: String, maxOutputTokens: Int, timeout: Double) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        let body: [String: JSONValue] = [
            "model": .string(model),
            "instructions": .string(system),
            "input": .array([.object(["role": .string("user"), "content": .string(user)])]),
            "max_output_tokens": .int(maxOutputTokens),
            "store": .bool(false),
            "text": .object(["format": .object([
                "type": .string("json_schema"),
                "name": .string(InsightSchema.name),
                "strict": .bool(true),
                "schema": InsightSchema.value,
            ])]),
        ]
        let (data, status) = try await HTTP.postJSON(
            url: baseURL.appendingPathComponent("responses"),
            headers: ["Authorization": "Bearer \(apiKey)"], body: body, timeout: timeout)
        guard (200..<300).contains(status) else {
            throw LLMError.httpStatus(status, Self.errorMessage(from: data))
        }
        let tree = try HTTP.decodeTree(data)
        return try Self.extractText(from: tree)
    }

    /// Walks `output[].content[]` for the first `output_text`, surfacing refusals.
    static func extractText(from tree: JSONValue) throws -> String {
        if let status = tree["status"]?.stringValue, status == "incomplete" {
            let reason = tree["incomplete_details"]?["reason"]?.stringValue ?? "incomplete"
            throw LLMError.malformed("Response incomplete: \(reason)")
        }
        for item in tree["output"]?.arrayValue ?? [] {
            guard item["type"]?.stringValue == "message" else { continue }
            for part in item["content"]?.arrayValue ?? [] {
                switch part["type"]?.stringValue {
                case "output_text":
                    if let text = part["text"]?.stringValue, !text.isEmpty { return text }
                case "refusal":
                    throw LLMError.refusal(part["refusal"]?.stringValue ?? "refused")
                default: continue
                }
            }
        }
        throw LLMError.emptyOutput
    }

    static func errorMessage(from data: Data) -> String {
        guard let tree = try? HTTP.decodeTree(data) else { return String(decoding: data.prefix(160), as: UTF8.self) }
        return tree["error"]?["message"]?.stringValue ?? "unknown error"
    }
}
