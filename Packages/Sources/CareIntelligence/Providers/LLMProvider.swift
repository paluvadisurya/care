import Foundation
import CareCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The model vendors the app can talk to. Bring a key for either; the app picks the active one.
public enum ProviderID: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case openAI
    case deepSeek

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .deepSeek: "DeepSeek"
        }
    }

    public var keyHint: String {
        switch self {
        case .openAI: "sk-…"
        case .deepSeek: "sk-…"
        }
    }

    public var docsURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .deepSeek: URL(string: "https://platform.deepseek.com/api_keys")!
        }
    }
}

/// Model names live here and nowhere else, so they can be swapped without a release.
public struct ModelConfig: Codable, Hashable, Sendable {
    public var provider: ProviderID
    public var dailyModel: String       // person, module and home insights
    public var weeklyModel: String      // Sunday deep insight
    public var maxOutputTokens: Int
    public var timeoutSeconds: Double

    public init(provider: ProviderID, dailyModel: String, weeklyModel: String, maxOutputTokens: Int = 900, timeoutSeconds: Double = 40) {
        self.provider = provider
        self.dailyModel = dailyModel
        self.weeklyModel = weeklyModel
        self.maxOutputTokens = maxOutputTokens
        self.timeoutSeconds = timeoutSeconds
    }

    /// Defaults as listed on each vendor's models page in September 2026. Editable in You › Intelligence.
    public static func `default`(for provider: ProviderID) -> ModelConfig {
        switch provider {
        case .openAI: ModelConfig(provider: .openAI, dailyModel: "gpt-5.6-luna", weeklyModel: "gpt-5.6-terra")
        case .deepSeek: ModelConfig(provider: .deepSeek, dailyModel: "deepseek-chat", weeklyModel: "deepseek-reasoner")
        }
    }
}

public enum LLMError: Error, Sendable, Equatable, LocalizedError {
    case missingKey
    case network(String)
    case httpStatus(Int, String)
    case refusal(String)
    case emptyOutput
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .missingKey: "No API key saved."
        case .network(let s): "Could not reach the model. \(s)"
        case .httpStatus(let code, let body): "The model returned \(code). \(body.prefix(160))"
        case .refusal(let s): "The model declined: \(s)"
        case .emptyOutput: "The model returned nothing."
        case .malformed(let s): "The model answer was not valid JSON. \(s.prefix(120))"
        }
    }
}

/// One request, one JSON answer. Providers own the wire format; nothing above them knows HTTP.
public protocol LLMProvider: Sendable {
    var id: ProviderID { get }
    /// Returns the raw JSON text of the model's answer.
    func generateJSON(system: String, user: String, model: String, maxOutputTokens: Int, timeout: Double) async throws -> String
}

/// Where API keys live. The Keychain on Apple platforms, memory in tests.
public protocol SecretStore: Sendable {
    func secret(for provider: ProviderID) -> String?
    func setSecret(_ value: String?, for provider: ProviderID)
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var values: [ProviderID: String] = [:]
    private let lock = NSLock()
    public init(_ values: [ProviderID: String] = [:]) { self.values = values }
    public func secret(for provider: ProviderID) -> String? { lock.withLock { values[provider] } }
    public func setSecret(_ value: String?, for provider: ProviderID) { lock.withLock { values[provider] = value } }
}

/// Minimal HTTP plumbing shared by providers. Strips the key from any error text.
enum HTTP {
    static func postJSON(url: URL, headers: [String: String], body: [String: JSONValue], timeout: Double) async throws -> (Data, Int) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try PayloadCoder.encoder.encode(JSONValue.object(body))
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, status)
        } catch {
            throw LLMError.network(error.localizedDescription)
        }
    }

    static func decodeTree(_ data: Data) throws -> JSONValue {
        do { return try PayloadCoder.decoder.decode(JSONValue.self, from: data) }
        catch { throw LLMError.malformed(String(decoding: data.prefix(200), as: UTF8.self)) }
    }
}
