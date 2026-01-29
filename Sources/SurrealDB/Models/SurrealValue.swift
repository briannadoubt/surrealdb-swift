import Foundation

/// A dynamic value type that can represent any JSON value in the SurrealDB protocol.
///
/// This type bridges between Swift's type-safe `Codable` world and the dynamic
/// JSON-RPC protocol used by SurrealDB.
public enum SurrealValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([SurrealValue])
    case object([String: SurrealValue])

    /// Creates a SurrealValue from any Encodable value.
    public init<T: Encodable>(from value: T) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let decoder = JSONDecoder()
        self = try decoder.decode(SurrealValue.self, from: data)
    }

    /// Decodes this value to a specific Decodable type.
    public func decode<T: Decodable>(as type: T.Type = T.self) throws -> T {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Accesses array elements by index.
    public subscript(index: Int) -> SurrealValue? {
        guard case .array(let array) = self, array.indices.contains(index) else {
            return nil
        }
        return array[index]
    }

    /// Accesses object properties by key.
    public subscript(key: String) -> SurrealValue? {
        guard case .object(let dict) = self else {
            return nil
        }
        return dict[key]
    }
}

// MARK: - Codable

extension SurrealValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([SurrealValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: SurrealValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode SurrealValue"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
}

// MARK: - CustomStringConvertible

extension SurrealValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null:
            return "null"
        case .bool(let bool):
            return "\(bool)"
        case .int(let int):
            return "\(int)"
        case .double(let double):
            return "\(double)"
        case .string(let string):
            return "\"\(string)\""
        case .array(let array):
            return "[\(array.map(\.description).joined(separator: ", "))]"
        case .object(let object):
            let pairs = object.map { "\"\($0.key)\": \($0.value.description)" }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

// MARK: - Convenience Initializers

extension SurrealValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension SurrealValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension SurrealValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension SurrealValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension SurrealValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension SurrealValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SurrealValue...) {
        self = .array(elements)
    }
}

extension SurrealValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, SurrealValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
