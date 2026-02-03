/// Schema management types for SurrealDB.
///
/// This file contains the foundation types used to define and manage database schemas,
/// including tables, fields, and indexes.

/// Defines the schema enforcement mode for a table.
public enum SchemaMode: String, Sendable, Equatable, Codable {
    /// Table accepts any fields (default).
    case schemaless

    /// Table only accepts defined fields.
    case schemafull

    /// Generates the SurrealQL representation.
    public func toSurrealQL() -> String {
        switch self {
        case .schemaless:
            return "SCHEMALESS"
        case .schemafull:
            return "SCHEMAFULL"
        }
    }
}

/// Defines the type of table.
public enum TableType: Sendable, Equatable, Codable {
    /// Standard table for storing records.
    case normal

    /// Edge table for graph relationships between two record types.
    case relation(from: String, to: String)

    /// Generates the SurrealQL representation.
    public func toSurrealQL() -> String {
        switch self {
        case .normal:
            return ""
        case .relation(let from, let to):
            return "TYPE RELATION IN \(from) OUT \(to)"
        }
    }
}

/// Defines the data type for a field.
public indirect enum FieldType: Sendable, Equatable, Codable, Hashable {
    /// Any type.
    case any

    /// String type.
    case string

    /// Number type (generic).
    case number

    /// Integer type.
    case int

    /// Float type.
    case float

    /// Decimal type.
    case decimal

    /// Boolean type.
    case bool

    /// DateTime type.
    case datetime

    /// Duration type.
    case duration

    /// UUID type.
    case uuid

    /// Bytes type.
    case bytes

    /// Null type.
    case null

    /// Object type (generic).
    case object

    /// Array of a specific type.
    case array(of: FieldType, maxLength: Int? = nil)

    /// Set of a specific type.
    case set(of: FieldType)

    /// Record type (reference to another table).
    case record(table: String? = nil)

    /// Geometry type.
    case geometry(subtype: GeometryType? = nil)

    /// Optional type (allows null).
    case option(of: FieldType)

    /// Range type for value intervals.
    case range

    /// Literal type for enum-like values.
    case literal(values: [String])

    /// Regular expression type.
    case regex

    /// Either type allowing multiple alternatives.
    case either([FieldType])

    /// Generates the SurrealQL representation.
    public func toSurrealQL() -> String {
        // Handle simple scalar types
        if let scalar = scalarTypeSQL() {
            return scalar
        }

        // Handle complex types
        return complexTypeSQL()
    }

    /// Return SQL for simple scalar types, or nil if not a scalar
    private func scalarTypeSQL() -> String? {
        if let numericType = numericTypeSQL() {
            return numericType
        }
        if let temporalType = temporalTypeSQL() {
            return temporalType
        }
        if let otherType = otherScalarTypeSQL() {
            return otherType
        }
        return nil
    }

    /// Return SQL for numeric scalar types
    private func numericTypeSQL() -> String? {
        switch self {
        case .number: return "number"
        case .int: return "int"
        case .float: return "float"
        case .decimal: return "decimal"
        default: return nil
        }
    }

    /// Return SQL for temporal scalar types
    private func temporalTypeSQL() -> String? {
        switch self {
        case .datetime: return "datetime"
        case .duration: return "duration"
        default: return nil
        }
    }

    /// Return SQL for other scalar types
    private func otherScalarTypeSQL() -> String? {
        switch self {
        case .any: return "any"
        case .string: return "string"
        case .bool: return "bool"
        case .uuid: return "uuid"
        case .bytes: return "bytes"
        case .null: return "null"
        case .object: return "object"
        case .range: return "range"
        case .regex: return "regex"
        default: return nil
        }
    }

    /// Return SQL for complex parameterized types
    private func complexTypeSQL() -> String {
        switch self {
        case .array(let type, let maxLength):
            return formatArrayType(type, maxLength: maxLength)
        case .set(let type):
            return formatGenericType("set", type)
        case .record(let table):
            return formatRecordType(table)
        case .geometry(let subtype):
            return formatGeometryType(subtype)
        case .option(let type):
            return formatGenericType("option", type)
        case .literal(let values):
            return formatLiteralType(values)
        case .either(let types):
            return formatEitherType(types)
        default:
            // Should not reach here if scalarTypeSQL handled all scalars
            return "any"
        }
    }

    /// Format a generic type like array<T>, set<T>, or option<T>
    private func formatGenericType(_ typeName: String, _ innerType: FieldType) -> String {
        "\(typeName)<\(innerType.toSurrealQL())>"
    }

    /// Format an array type with optional maxLength constraint
    private func formatArrayType(_ innerType: FieldType, maxLength: Int?) -> String {
        if let maxLength = maxLength {
            return "array<\(innerType.toSurrealQL()), \(maxLength)>"
        } else {
            return "array<\(innerType.toSurrealQL())>"
        }
    }

    /// Format a record type with optional table specifier
    private func formatRecordType(_ table: String?) -> String {
        if let table = table {
            return "record<\(table)>"
        } else {
            return "record"
        }
    }

    /// Format a geometry type with optional subtype
    private func formatGeometryType(_ subtype: GeometryType?) -> String {
        if let subtype = subtype {
            return "geometry<\(subtype.toSurrealQL())>"
        } else {
            return "geometry"
        }
    }

    /// Format a literal type with enum-like values
    private func formatLiteralType(_ values: [String]) -> String {
        values.map { "\"\($0)\"" }.joined(separator: " | ")
    }

    /// Format an either type with multiple alternatives
    private func formatEitherType(_ types: [FieldType]) -> String {
        types.map { $0.toSurrealQL() }.joined(separator: " | ")
    }
}

/// Geometry subtypes for the geometry field type.
public enum GeometryType: String, Sendable, Equatable, Codable, Hashable {
    /// Point geometry.
    case point

    /// LineString geometry.
    case lineString = "linestring"

    /// Polygon geometry.
    case polygon

    /// MultiPoint geometry.
    case multiPoint = "multipoint"

    /// MultiLineString geometry.
    case multiLineString = "multilinestring"

    /// MultiPolygon geometry.
    case multiPolygon = "multipolygon"

    /// GeometryCollection.
    case collection

    /// Generates the SurrealQL representation.
    public func toSurrealQL() -> String {
        rawValue
    }
}

/// Defines the type of index.
public enum IndexType: Sendable, Equatable, Codable, Hashable {
    /// Standard index for efficient lookups.
    case standard

    /// Unique index ensuring uniqueness.
    case unique

    /// Full-text search index.
    case fulltext(analyzer: String? = nil)

    /// Search index for advanced text search.
    case search(analyzer: String? = nil)

    /// Generates the SurrealQL representation.
    public func toSurrealQL() -> String {
        switch self {
        case .standard:
            return ""
        case .unique:
            return "UNIQUE"
        case .fulltext(let analyzer):
            if let analyzer = analyzer {
                return "SEARCH ANALYZER \(analyzer) BM25"
            } else {
                return "SEARCH ANALYZER LIKE BM25"
            }
        case .search(let analyzer):
            if let analyzer = analyzer {
                return "SEARCH ANALYZER \(analyzer)"
            } else {
                return "SEARCH ANALYZER LIKE"
            }
        }
    }
}
