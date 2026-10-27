import Foundation

/// A generic, Sendable representation of an arbitrary JSON value.
///
/// Used for `_meta`-style fields, opaque tool-call payloads, and generic
/// request/response parameter passthrough.
public enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSONValue {
    /// Encodes any `Encodable` value into a ``JSONValue`` by round-tripping through `JSONEncoder`/`JSONDecoder`.
    public init<T: Encodable>(encoding value: T) throws {
        let data = try JSONEncoder.jsonrpcEncoder.encode(value)
        self = try JSONDecoder.jsonrpcDecoder.decode(JSONValue.self, from: data)
    }

    /// Decodes this ``JSONValue`` into a concrete `Decodable` type by round-tripping through `JSONEncoder`/`JSONDecoder`.
    public func decode<T: Decodable>(as type: T.Type = T.self) throws -> T {
        let data = try JSONEncoder.jsonrpcEncoder.encode(self)
        return try JSONDecoder.jsonrpcDecoder.decode(T.self, from: data)
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}

extension JSONEncoder {
    static let jsonrpcEncoder: JSONEncoder = JSONEncoder()
}

extension JSONDecoder {
    static let jsonrpcDecoder: JSONDecoder = JSONDecoder()
}

extension JSONValue {
    /// Encodes `payload` and merges in a string discriminator field, for protocols
    /// that model unions as self-describing objects tagged by a `"type"`-style field.
    public static func taggedObject<T: Encodable>(tag key: String, value: String, payload: T) throws
        -> JSONValue
    {
        var object = try JSONValue(encoding: payload).objectValue ?? [:]
        object[key] = .string(value)
        return .object(object)
    }
}
