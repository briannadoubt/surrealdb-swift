import Foundation

// Note: FieldType, GeometryType, and IndexType are defined in SchemaTypes.swift
// This file uses those shared types to avoid duplication.

// MARK: - Field Descriptor

/// Describes a single field in a SurrealDB table.
public struct FieldDescriptor: Sendable, Codable, Hashable {
    /// The field name as it appears in the database
    public let name: String

    /// The field's type
    public let type: FieldType

    /// Whether this field is optional
    public let isOptional: Bool

    /// Whether this field has an index
    public let hasIndex: Bool

    /// The type of index, if any
    public let indexType: IndexType?

    /// Whether this is a computed field
    public let isComputed: Bool

    /// The SurrealQL expression for computed fields
    public let computedExpression: String?

    /// Whether this is a relation field
    public let isRelation: Bool

    /// Default value for the field (as SurrealQL string)
    public let defaultValue: String?

    /// Field assertions/validations
    public let assertions: [String]

    /// Field permissions
    public let permissions: FieldPermissions?

    public init(
        name: String,
        type: FieldType,
        isOptional: Bool = false,
        hasIndex: Bool = false,
        indexType: IndexType? = nil,
        isComputed: Bool = false,
        computedExpression: String? = nil,
        isRelation: Bool = false,
        defaultValue: String? = nil,
        assertions: [String] = [],
        permissions: FieldPermissions? = nil
    ) {
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.hasIndex = hasIndex
        self.indexType = indexType
        self.isComputed = isComputed
        self.computedExpression = computedExpression
        self.isRelation = isRelation
        self.defaultValue = defaultValue
        self.assertions = assertions
        self.permissions = permissions
    }

    /// Generate DEFINE FIELD statement
    public func toSurrealQL(tableName: String) -> String {
        var parts: [String] = []

        // DEFINE FIELD name
        parts.append("DEFINE FIELD \(name)")
        parts.append("ON TABLE \(tableName)")

        // TYPE
        if isOptional {
            parts.append("TYPE option<\(type.toSurrealQL())>")
        } else {
            parts.append("TYPE \(type.toSurrealQL())")
        }

        // DEFAULT
        if let defaultValue = defaultValue {
            parts.append("DEFAULT \(defaultValue)")
        }

        // VALUE (for computed fields)
        if let expression = computedExpression {
            parts.append("VALUE \(expression)")
        }

        // ASSERT
        if !assertions.isEmpty {
            for assertion in assertions {
                parts.append("ASSERT \(assertion)")
            }
        }

        // PERMISSIONS
        if let perms = permissions {
            if let select = perms.select {
                parts.append("PERMISSIONS FOR select \(select)")
            }
            if let create = perms.create {
                parts.append("FOR create \(create)")
            }
            if let update = perms.update {
                parts.append("FOR update \(update)")
            }
            if let delete = perms.delete {
                parts.append("FOR delete \(delete)")
            }
        }

        return parts.joined(separator: " ") + ";"
    }
}

// MARK: - Field Permissions

/// Permissions for a specific field
public struct FieldPermissions: Sendable, Codable, Hashable {
    public let select: String?
    public let create: String?
    public let update: String?
    public let delete: String?

    public init(
        select: String? = nil,
        create: String? = nil,
        update: String? = nil,
        delete: String? = nil
    ) {
        self.select = select
        self.create = create
        self.update = update
        self.delete = delete
    }
}

// MARK: - Schema Descriptor

/// Complete schema description for a SurrealDB table.
public struct SchemaDescriptor: Sendable, Codable, Hashable {
    /// The table name
    public let tableName: String

    /// All fields in this table
    public let fields: [FieldDescriptor]

    /// Whether this is an edge table
    public let isEdge: Bool

    /// For edge tables, the source (From) table name
    public let edgeFrom: String?

    /// For edge tables, the target (To) table name
    public let edgeTo: String?

    /// Table-level permissions
    public let permissions: TablePermissions?

    public init(
        tableName: String,
        fields: [FieldDescriptor],
        isEdge: Bool = false,
        edgeFrom: String? = nil,
        edgeTo: String? = nil,
        permissions: TablePermissions? = nil
    ) {
        self.tableName = tableName
        self.fields = fields
        self.isEdge = isEdge
        self.edgeFrom = edgeFrom
        self.edgeTo = edgeTo
        self.permissions = permissions
    }

    /// Generate complete DEFINE TABLE statement
    public func toSurrealQL() -> String {
        var statements: [String] = []

        // DEFINE TABLE
        var tableDefParts: [String] = ["DEFINE TABLE \(tableName)"]

        if isEdge {
            tableDefParts.append("TYPE RELATION")
            if let from = edgeFrom {
                tableDefParts.append("FROM \(from)")
            }
            if let to = edgeTo {
                tableDefParts.append("TO \(to)")
            }
        } else {
            tableDefParts.append("TYPE NORMAL")
        }

        tableDefParts.append("SCHEMAFULL")

        // Add permissions if specified
        if let perms = permissions {
            if let select = perms.select {
                tableDefParts.append("PERMISSIONS FOR select \(select)")
            }
            if let create = perms.create {
                tableDefParts.append("FOR create \(create)")
            }
            if let update = perms.update {
                tableDefParts.append("FOR update \(update)")
            }
            if let delete = perms.delete {
                tableDefParts.append("FOR delete \(delete)")
            }
        }

        statements.append(tableDefParts.joined(separator: " ") + ";")

        // DEFINE FIELDs
        for field in fields where !field.isRelation {
            statements.append(field.toSurrealQL(tableName: tableName))
        }

        // DEFINE INDEXes
        for field in fields where field.hasIndex {
            if let indexType = field.indexType {
                let indexName = "idx_\(tableName)_\(field.name)"
                let typeSQL = indexType.toSurrealQL()
                let typePart = typeSQL.isEmpty ? "" : " \(typeSQL)"
                statements.append(
                    "DEFINE INDEX \(indexName) ON TABLE \(tableName) FIELDS \(field.name)\(typePart);"
                )
            }
        }

        return statements.joined(separator: "\n")
    }
}

// MARK: - Table Permissions

/// Table-level permissions
public struct TablePermissions: Sendable, Codable, Hashable {
    public let select: String?
    public let create: String?
    public let update: String?
    public let delete: String?

    public init(
        select: String? = nil,
        create: String? = nil,
        update: String? = nil,
        delete: String? = nil
    ) {
        self.select = select
        self.create = create
        self.update = update
        self.delete = delete
    }
}

// MARK: - HasSchemaDescriptor Protocol

/// Protocol for types that have schema metadata.
/// This is typically added by the @Surreal macro.
public protocol HasSchemaDescriptor {
    /// The schema descriptor for this type
    static var _schemaDescriptor: SchemaDescriptor { get } // swiftlint:disable:this identifier_name
}

// MARK: - Schema Registration

/// Global registry for schema descriptors.
/// This allows runtime schema discovery and migration.
public final class SchemaRegistry: @unchecked Sendable {
    public static let shared = SchemaRegistry()

    private var schemas: [String: SchemaDescriptor] = [:]
    private let lock = NSLock()

    private init() {}

    /// Register a schema descriptor
    public func register(_ schema: SchemaDescriptor) {
        lock.lock()
        defer { lock.unlock() }
        schemas[schema.tableName] = schema
    }

    /// Get a registered schema by table name
    public func schema(for tableName: String) -> SchemaDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return schemas[tableName]
    }

    /// Get all registered schemas
    public func allSchemas() -> [SchemaDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return Array(schemas.values)
    }

    /// Generate SurrealQL for all registered schemas
    public func generateSurrealQL() -> String {
        let allSchemas = allSchemas()
        return allSchemas
            .map { $0.toSurrealQL() }
            .joined(separator: "\n\n")
    }
}
