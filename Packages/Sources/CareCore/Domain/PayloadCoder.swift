import Foundation

/// One coder for every module payload, so dates and keys round-trip identically everywhere.
public enum PayloadCoder {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    /// A stable hash of any encodable value, used to skip model calls when inputs have not changed.
    public static func inputHash<T: Encodable>(_ value: T) -> String {
        guard let data = try? encode(value) else { return "0" }
        return FNV1a.hash(data)
    }
}

/// Small non-cryptographic hash. Stable across launches, which `Hasher` is not.
public enum FNV1a {
    public static func hash(_ data: Data) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in data {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return String(h, radix: 16)
    }

    public static func hash(_ string: String) -> String {
        hash(Data(string.utf8))
    }
}
