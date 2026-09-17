import Foundation

/// A tiny JSON tree used for context packs, so modules can hand the model compact data without a shared schema.
public indirect enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n):
            if n == n.rounded(), abs(n) < 1e15 { try c.encode(Int(n)) } else { try c.encode(n) }
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    // MARK: Convenience constructors

    public static func int(_ v: Int) -> JSONValue { .number(Double(v)) }
    public static func date(_ d: Date) -> JSONValue { .string(CareDates.isoDay(d)) }
    public static func optional(_ s: String?) -> JSONValue { s.map { .string($0) } ?? .null }

    public var stringValue: String? { if case .string(let s) = self { return s } else { return nil } }
    public var doubleValue: Double? { if case .number(let n) = self { return n } else { return nil } }
    public var intValue: Int? { doubleValue.map { Int($0) } }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a } else { return nil } }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o } else { return nil } }

    public subscript(key: String) -> JSONValue? { objectValue?[key] }

    /// Pretty-ish compact text for prompts.
    public var compactText: String {
        guard let data = try? PayloadCoder.encoder.encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
