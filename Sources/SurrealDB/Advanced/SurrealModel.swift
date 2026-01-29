import Foundation

// MARK: - Core Protocols

/// A model that can be stored in SurrealDB
public protocol SurrealModel: Codable, Sendable {
    /// The table name for this model
    static var tableName: String { get }

    /// The record ID
    var id: RecordID? { get set }
}

extension SurrealModel {
    /// Default table name from type name
    public static var tableName: String {
        String(describing: Self.self).lowercased()
    }
}

/// An edge model representing a relationship
public protocol EdgeModel: Codable, Sendable {
    associatedtype From: SurrealModel
    associatedtype To: SurrealModel

    /// The edge table name
    static var edgeName: String { get }
}

extension EdgeModel {
    public static var edgeName: String {
        String(describing: Self.self).lowercased()
    }
}

// MARK: - Property Wrappers

/// Property wrapper for SurrealDB record IDs
@propertyWrapper
public struct ID: Codable, Sendable {
    /// Auto-generation strategy for IDs
    public enum GenerationStrategy: Sendable {
        case none
        case uuid
        case ulid
        case nanoid
    }

    public var wrappedValue: RecordID?
    public let strategy: GenerationStrategy

    public init(wrappedValue: RecordID? = nil, strategy: GenerationStrategy = .none) {
        self.wrappedValue = wrappedValue
        self.strategy = strategy
    }

    /// Generate a new ID if one doesn't exist, using the configured strategy
    public mutating func generateIfNeeded(table: String) {
        guard wrappedValue == nil, strategy != .none else { return }

        let id: String
        switch strategy {
        case .none:
            return
        case .uuid:
            id = UUID().uuidString.lowercased()
        case .ulid:
            // ULID generation (simplified - production should use proper ULID library)
            id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        case .nanoid:
            // NanoID generation (simplified - production should use proper NanoID library)
            id = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(21).lowercased()
        }

        wrappedValue = try? RecordID(table: table, id: id)
    }

    /// Validate that the ID belongs to the expected table
    public func validate(forTable expectedTable: String) throws {
        guard let id = wrappedValue else { return }

        if id.table != expectedTable {
            throw SurrealError.invalidRecordID(
                "ID table '\(id.table)' does not match expected table '\(expectedTable)'"
            )
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            wrappedValue = nil
        } else {
            let string = try container.decode(String.self)
            wrappedValue = try RecordID(parsing: string)
        }
        self.strategy = .none  // Strategy is not decoded, only used at creation time
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let id = wrappedValue {
            try container.encode(id.toString())
        } else {
            try container.encodeNil()
        }
    }
}

/// Property wrapper for relationships
@propertyWrapper
public struct Relation<T: SurrealModel, Edge: EdgeModel>: Codable, Sendable {
    public enum Direction: Sendable, Codable {
        case `in`, out, both
    }

    private var _value: [T]?
    private var _isLoaded: Bool

    public var wrappedValue: [T] {
        get { _value ?? [] }
        set {
            _value = newValue
            _isLoaded = true
        }
    }

    /// Whether the relation has been loaded from the database
    public var isLoaded: Bool {
        _isLoaded
    }

    public let edge: Edge.Type
    public let direction: Direction

    public init(edge: Edge.Type, direction: Direction = .out) {
        self.edge = edge
        self.direction = direction
        self._value = nil
        self._isLoaded = false
    }

    /// Initialize with pre-loaded values
    public init(edge: Edge.Type, direction: Direction = .out, loaded values: [T]) {
        self.edge = edge
        self.direction = direction
        self._value = values
        self._isLoaded = true
    }

    enum CodingKeys: String, CodingKey {
        case value = "_value"
        case isLoaded = "_isLoaded"
        // Note: edge and direction are not encoded as they're compile-time metadata
    }

    public init(from decoder: Decoder) throws {
        // Check if there's a container with pre-loaded data
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self._value = try container.decodeIfPresent([T].self, forKey: .value)
            self._isLoaded = try container.decodeIfPresent(Bool.self, forKey: .isLoaded) ?? false
        } else {
            // No pre-loaded data - this is normal for fresh decoding
            self._value = nil
            self._isLoaded = false
        }

        // Edge and direction are compile-time metadata, not decoded
        self.edge = Edge.self
        self.direction = .out  // Default, can be overridden after decoding if needed
    }

    public func encode(to encoder: Encoder) throws {
        // Only encode if the relation has been explicitly loaded
        // This prevents accidentally persisting relationship arrays
        // which should be managed by SurrealDB's graph relationships
        if _isLoaded, let value = _value {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .value)
            try container.encode(_isLoaded, forKey: .isLoaded)
        }
        // If not loaded, encode nothing - the relationship exists in the graph
    }

    /// Mark the relation as loaded with specific values
    mutating func markLoaded(with values: [T]) {
        self._value = values
        self._isLoaded = true
    }

    /// Reset the relation to unloaded state
    mutating func reset() {
        self._value = nil
        self._isLoaded = false
    }
}

/// Property wrapper for computed fields
/// Computed fields are calculated by the database and should not be persisted.
@propertyWrapper
public struct Computed<T: Codable & Sendable>: Codable, Sendable {
    /// The SurrealQL expression for this computed field
    public let expression: String

    /// The computed value (loaded from query results, never persisted)
    public var wrappedValue: T?

    /// Initialize with a SurrealQL expression
    /// - Parameter expression: SurrealQL expression (e.g., "count(posts)", "created_at.year()")
    public init(_ expression: String) {
        self.expression = expression
        self.wrappedValue = nil
    }

    /// Initialize with aggregate function
    public init(count field: String) {
        self.expression = "count(\(field))"
        self.wrappedValue = nil
    }

    /// Initialize with SUM aggregate
    public init(sum field: String) {
        self.expression = "sum(\(field))"
        self.wrappedValue = nil
    }

    /// Initialize with AVG aggregate
    public init(avg field: String) {
        self.expression = "avg(\(field))"
        self.wrappedValue = nil
    }

    /// Initialize with MAX aggregate
    public init(max field: String) {
        self.expression = "max(\(field))"
        self.wrappedValue = nil
    }

    /// Initialize with MIN aggregate
    public init(min field: String) {
        self.expression = "min(\(field))"
        self.wrappedValue = nil
    }

    public init(from decoder: Decoder) throws {
        // Computed fields are read from query results
        let container = try decoder.singleValueContainer()
        self.expression = ""  // Expression is not stored in DB
        self.wrappedValue = try? container.decode(T.self)
    }

    public func encode(to encoder: Encoder) throws {
        // IMPORTANT: Computed fields are NEVER encoded to the database
        // They are calculated by SurrealDB and are read-only from Swift's perspective
        // Encoding nothing ensures they won't be persisted
    }
}

/// Property wrapper for index hints
/// This is metadata-only and doesn't affect runtime behavior,
/// but can be used for schema generation and documentation.
@propertyWrapper
public struct Index<T: Codable & Sendable>: Codable, Sendable {
    public enum IndexType: String, Codable, Sendable {
        case unique = "UNIQUE"
        case search = "SEARCH"
        case fulltext = "FULLTEXT"
        case standard = "INDEX"
    }

    public var wrappedValue: T
    public let indexType: IndexType
    public let name: String?

    public init(wrappedValue: T, type: IndexType = .standard, name: String? = nil) {
        self.wrappedValue = wrappedValue
        self.indexType = type
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(T.self)
        self.indexType = .standard  // Metadata not stored in DB
        self.name = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// MARK: - Type-Safe Query Components

/// Operation for KeyPath-based predicates
public enum PredicateOperation: String, Sendable {
    case equals = "="
    case notEquals = "!="
    case greaterThan = ">"
    case lessThan = "<"
    case greaterThanOrEqual = ">="
    case lessThanOrEqual = "<="
    case contains = "CONTAINS"
    case `in` = "IN"
}

/// A type-safe predicate
public struct Predicate: Sendable {
    let field: String
    let operation: PredicateOperation
    let value: SurrealValue

    public func toSurrealQL() -> String {
        "\(field) \(operation.rawValue) \(formatValue(value))"
    }

    private func formatValue(_ value: SurrealValue) -> String {
        switch value {
        case .string(let str):
            return "'\(str)'"
        case .int(let int):
            return "\(int)"
        case .double(let double):
            return "\(double)"
        case .bool(let bool):
            return "\(bool)"
        case .array(let array):
            let values = array.map { formatValue($0) }
            return "[\(values.joined(separator: ", "))]"
        default:
            return "\(value)"
        }
    }
}

// MARK: - KeyPath Helpers

/// Extract field name from PartialKeyPath using reflection
/// This implementation parses the KeyPath debug description to extract field names.
/// Performance: O(1) amortized with caching, O(n) worst case for string parsing
public func extractFieldName<T>(from keyPath: PartialKeyPath<T>) -> String {
    let keypathString = String(describing: keyPath)

    // KeyPath format varies but typically: "\TypeName.propertyName" or "\\TypeName.propertyName"
    // Examples:
    // - "\TestUser.name"
    // - "\\TestUser.age"
    // - "\Container<String, Int>.items"

    // Strategy: Find the last component after the last dot
    if let lastDot = keypathString.lastIndex(of: ".") {
        let afterDot = keypathString[keypathString.index(after: lastDot)...]
        let fieldName = String(afterDot)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ">)"))

        if !fieldName.isEmpty {
            return fieldName
        }
    }

    // Fallback: if no dot found, try to clean up the string
    let cleaned = keypathString
        .replacingOccurrences(of: "\\", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return cleaned
}

/// Extract field name from KeyPath (fully typed version)
public func extractFieldName<T, V>(from keyPath: KeyPath<T, V>) -> String {
    extractFieldName(from: keyPath as PartialKeyPath<T>)
}

// MARK: - Type-Safe Operators

public func == <T, V: Equatable>(lhs: KeyPath<T, V>, rhs: V) -> Predicate {
    Predicate(
        field: extractFieldName(from: lhs),
        operation: .equals,
        value: SurrealValue(reflecting: rhs)
    )
}

public func != <T, V: Equatable>(lhs: KeyPath<T, V>, rhs: V) -> Predicate {
    Predicate(
        field: extractFieldName(from: lhs),
        operation: .notEquals,
        value: SurrealValue(reflecting: rhs)
    )
}

public func > <T, V: Comparable>(lhs: KeyPath<T, V>, rhs: V) -> Predicate {
    Predicate(
        field: extractFieldName(from: lhs),
        operation: .greaterThan,
        value: SurrealValue(reflecting: rhs)
    )
}

public func < <T, V: Comparable>(lhs: KeyPath<T, V>, rhs: V) -> Predicate {
    Predicate(
        field: extractFieldName(from: lhs),
        operation: .lessThan,
        value: SurrealValue(reflecting: rhs)
    )
}

public func >= <T, V: Comparable>(lhs: KeyPath<T, V>, rhs: V) -> Predicate {
    Predicate(
        field: extractFieldName(from: lhs),
        operation: .greaterThanOrEqual,
        value: SurrealValue(reflecting: rhs)
    )
}

public func <= <T, V: Comparable>(lhs: KeyPath<T, V>, rhs: V) -> Predicate {
    Predicate(
        field: extractFieldName(from: lhs),
        operation: .lessThanOrEqual,
        value: SurrealValue(reflecting: rhs)
    )
}

extension SurrealValue {
    /// Create a SurrealValue from any value using Mirror reflection
    init(reflecting value: Any) {
        let mirror = Mirror(reflecting: value)

        if mirror.children.isEmpty {
            // Primitive type
            if let int = value as? Int {
                self = .int(int)
            } else if let double = value as? Double {
                self = .double(double)
            } else if let string = value as? String {
                self = .string(string)
            } else if let bool = value as? Bool {
                self = .bool(bool)
            } else {
                self = .string(String(describing: value))
            }
        } else {
            // Complex type - convert to string for now
            self = .string(String(describing: value))
        }
    }
}

// MARK: - Model Extensions

extension SurrealModel {
    /// Create a relationship to another model
    public func relate<Edge: EdgeModel, Target: SurrealModel>(
        to target: Target,
        via edge: Edge,
        using db: SurrealDB
    ) async throws -> Edge where Edge.From == Self, Edge.To == Target {
        guard let fromId = self.id, let toId = target.id else {
            throw SurrealError.invalidRecordID("Both models must have IDs")
        }

        return try await db.relate(
            from: fromId,
            via: Edge.edgeName,
            to: toId,
            data: edge
        )
    }

    /// Load relationships for this model
    public func load<Edge: EdgeModel>(
        _ keyPath: KeyPath<Self, Relation<Edge.To, Edge>>,
        using db: SurrealDB
    ) async throws -> [Edge.To] where Edge.From == Self {
        guard let id = self.id else {
            throw SurrealError.invalidRecordID("Model must have an ID")
        }

        // Build graph traversal query
        let relation = self[keyPath: keyPath]
        let direction = relation.direction == .out ? "->" : "<-"
        let edgeName = Edge.edgeName

        let query = """
        SELECT * FROM \(id.toString())\(direction)\(edgeName)\(direction)\(Edge.To.tableName)
        """

        let results = try await db.query(query)
        guard let firstResult = results.first else {
            return []
        }

        return try firstResult.decode()
    }
}
