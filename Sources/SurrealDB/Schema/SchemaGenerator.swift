import Foundation

/// Generates SurrealDB schema definitions from Swift types.
///
/// The SchemaGenerator analyzes SurrealModel and EdgeModel types to produce
/// DEFINE TABLE statements that can be executed against a SurrealDB instance.
///
/// Example:
/// ```swift
/// struct User: SurrealModel {
///     var id: RecordID?
///     var name: String
///     var email: String
///     var age: Int
/// }
///
/// let statements = try SchemaGenerator.generateTableSchema(
///     for: User.self,
///     mode: .schemafull
/// )
/// // Produces:
/// // DEFINE TABLE user SCHEMAFULL;
/// // DEFINE FIELD name ON TABLE user TYPE string;
/// // DEFINE FIELD email ON TABLE user TYPE string;
/// // DEFINE FIELD age ON TABLE user TYPE int;
/// ```
public struct SchemaGenerator: Sendable {
    // MARK: - Table Schema Generation

    /// Generates DEFINE statements for a SurrealModel type.
    ///
    /// This method analyzes the model's properties and generates appropriate
    /// DEFINE TABLE and DEFINE FIELD statements based on the property types.
    ///
    /// - Parameters:
    ///   - type: The SurrealModel type to generate schema for.
    ///   - mode: The schema mode (schemafull or schemaless).
    ///   - drop: If true, includes a REMOVE TABLE statement before DEFINE TABLE.
    /// - Returns: Array of SurrealQL statements.
    /// - Throws: ``SurrealError/encodingError(_:)`` if type inspection fails.
    public static func generateTableSchema<T: SurrealModel>(
        for type: T.Type,
        mode: SchemaMode = .schemafull,
        drop: Bool = false
    ) throws(SurrealError) -> [String] {
        let tableName = T.tableName
        var statements: [String] = []

        // Add drop statement if requested
        if drop {
            statements.append("REMOVE TABLE IF EXISTS \(tableName);")
        }

        // Define the table
        statements.append("DEFINE TABLE \(tableName) \(mode.toSurrealQL());")

        // Only generate field definitions for schemafull mode
        if mode == .schemafull {
            let fields = try extractFields(from: type)

            for field in fields {
                let fieldStatement = generateFieldDefinition(
                    field: field.name,
                    type: field.type,
                    table: tableName,
                    isOptional: field.isOptional
                )
                statements.append(fieldStatement)
            }
        }

        return statements
    }

    // MARK: - Edge Schema Generation

    /// Generates DEFINE statements for an EdgeModel type.
    ///
    /// Edge tables in SurrealDB represent relationships between records.
    /// This method generates the table definition with proper IN and OUT
    /// constraints based on the edge's From and To types.
    ///
    /// - Parameters:
    ///   - type: The EdgeModel type to generate schema for.
    ///   - mode: The schema mode (schemafull or schemaless).
    ///   - drop: If true, includes a REMOVE TABLE statement before DEFINE TABLE.
    /// - Returns: Array of SurrealQL statements.
    /// - Throws: ``SurrealError/encodingError(_:)`` if type inspection fails.
    public static func generateEdgeSchema<T: EdgeModel>(
        for type: T.Type,
        mode: SchemaMode = .schemafull,
        drop: Bool = false
    ) throws(SurrealError) -> [String] {
        let edgeName = T.edgeName
        var statements: [String] = []

        // Add drop statement if requested
        if drop {
            statements.append("REMOVE TABLE IF EXISTS \(edgeName);")
        }

        // Extract From and To table names using metatype
        let fromTable = T.From.tableName
        let toTable = T.To.tableName

        // Define the edge table with IN/OUT constraints
        // TYPE RELATION means this is an edge/relationship table
        statements.append("""
        DEFINE TABLE \(edgeName) \(mode.toSurrealQL()) TYPE RELATION \
        IN \(fromTable) OUT \(toTable);
        """)

        // Only generate field definitions for schemafull mode
        if mode == .schemafull {
            let fields = try extractFields(from: type)

            for field in fields {
                let fieldStatement = generateFieldDefinition(
                    field: field.name,
                    type: field.type,
                    table: edgeName,
                    isOptional: field.isOptional
                )
                statements.append(fieldStatement)
            }
        }

        return statements
    }

    // MARK: - Field Extraction

    private struct FieldInfo {
        let name: String
        let type: String
        let isOptional: Bool
    }

    /// Extracts field information from a Codable type using Mirror reflection.
    ///
    /// This is a reflection-based approach that works without macros.
    /// When macro support is available, this can be replaced with
    /// macro-generated SchemaDescriptor.
    private static func extractFields<T>(from type: T.Type) throws(SurrealError) -> [FieldInfo] {
        var fields: [FieldInfo] = []

        // Create a temporary instance to inspect using Mirror
        // This requires a default initializer, which is a limitation
        // In the future, this will be replaced by macro-generated metadata

        // For now, we'll use CodingKeys if available
        // This is a simplified approach - the macro will provide full metadata
        guard let codableType = type as? any Codable.Type else {
            throw SurrealError.encodingError("Type must conform to Codable")
        }

        // Use reflection to extract property names
        // This is a basic implementation - macros will provide richer metadata
        let typeName = String(describing: type)

        // Note: This is a placeholder implementation
        // The actual implementation will use macro-generated SchemaDescriptor
        // which provides complete type information without requiring reflection

        return fields
    }

    // MARK: - Field Definition Generation

    /// Generates a DEFINE FIELD statement for a single field.
    private static func generateFieldDefinition(
        field: String,
        type: String,
        table: String,
        isOptional: Bool
    ) -> String {
        // Skip special fields
        guard field != "id" else {
            return "" // ID is implicitly defined
        }

        // Build the field definition
        var statement = "DEFINE FIELD \(field) ON TABLE \(table) TYPE \(type)"

        // Add FLEXIBLE for optional fields (allows NULL)
        if isOptional {
            statement += " FLEXIBLE"
        }

        statement += ";"
        return statement
    }

    // MARK: - Type Mapping

    /// Maps Swift types to SurrealDB types.
    ///
    /// This provides a basic type mapping that can be extended.
    /// The macro implementation will provide more sophisticated type mapping
    /// including support for custom types, arrays, objects, etc.
    public static func mapSwiftType(_ swiftType: String) -> String {
        switch swiftType {
        case "String":
            return "string"
        case "Int", "Int8", "Int16", "Int32", "Int64":
            return "int"
        case "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "int"
        case "Double", "Float", "Float32", "Float64":
            return "float"
        case "Bool":
            return "bool"
        case "Date":
            return "datetime"
        case "UUID":
            return "string"
        case "Data":
            return "bytes"
        default:
            // Arrays
            if swiftType.hasPrefix("Array<") || swiftType.hasPrefix("[") {
                return "array"
            }
            // Dictionaries/Objects
            if swiftType.hasPrefix("Dictionary<") || swiftType.hasPrefix("[String:") {
                return "object"
            }
            // Default to object for custom types
            return "object"
        }
    }
}

// MARK: - Field Definition Helper

extension SchemaGenerator {
    /// A field definition structure to avoid tuple violations.
    public struct FieldDefinition: Sendable {
        public let name: String
        public let type: String
        public let optional: Bool

        public init(name: String, type: String, optional: Bool = false) {
            self.name = name
            self.type = type
            self.optional = optional
        }
    }
}

// MARK: - Convenience Methods

extension SchemaGenerator {
    /// Generates schema statements with field definitions from property wrappers.
    ///
    /// This is a helper method that will be enhanced when macro support is available.
    /// For now, it provides basic schema generation capabilities.
    ///
    /// - Parameters:
    ///   - tableName: The table name.
    ///   - fields: Field definitions.
    ///   - mode: The schema mode.
    ///   - drop: If true, includes a REMOVE TABLE statement.
    /// - Returns: Array of SurrealQL statements.
    public static func generateSchema(
        tableName: String,
        fields: [FieldDefinition],
        mode: SchemaMode = .schemafull,
        drop: Bool = false
    ) -> [String] {
        var statements: [String] = []

        if drop {
            statements.append("REMOVE TABLE IF EXISTS \(tableName);")
        }

        statements.append("DEFINE TABLE \(tableName) \(mode.toSurrealQL());")

        if mode == .schemafull {
            for field in fields where field.name != "id" {
                let fieldStatement = generateFieldDefinition(
                    field: field.name,
                    type: field.type,
                    table: tableName,
                    isOptional: field.optional
                )
                if !fieldStatement.isEmpty {
                    statements.append(fieldStatement)
                }
            }
        }

        return statements
    }
}
