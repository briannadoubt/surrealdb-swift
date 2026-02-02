import Foundation

/// A builder for defining table fields with a fluent API.
///
/// This builder provides a type-safe, chainable interface for creating field definitions
/// in SurrealDB. It supports field types, default values, assertions, and various
/// configuration options.
///
/// ## Example
///
/// ```swift
/// // Define a required string field
/// try await db.schema
///     .defineField("email", on: "users")
///     .type(.string)
///     .assert("string::is::email($value)")
///     .execute()
///
/// // Define an optional field with default
/// try await db.schema
///     .defineField("status", on: "users")
///     .type(.option(of: .string))
///     .default("active")
///     .execute()
/// ```
public struct FieldDefinitionBuilder: Sendable {
    private let client: SurrealDB
    private let fieldName: String
    private let tableName: String
    private let fieldType: FieldType?
    private let defaultValue: String?
    private let valueExpression: String?
    private let assertExpression: String?
    private let isFlexible: Bool
    private let shouldIfNotExists: Bool

    /// Creates a new field definition builder.
    ///
    /// - Parameters:
    ///   - client: The SurrealDB client to use for execution.
    ///   - fieldName: The name of the field to define.
    ///   - tableName: The name of the table containing this field.
    internal init(
        client: SurrealDB,
        fieldName: String,
        tableName: String,
        fieldType: FieldType? = nil,
        defaultValue: String? = nil,
        valueExpression: String? = nil,
        assertExpression: String? = nil,
        isFlexible: Bool = false,
        shouldIfNotExists: Bool = false
    ) {
        self.client = client
        self.fieldName = fieldName
        self.tableName = tableName
        self.fieldType = fieldType
        self.defaultValue = defaultValue
        self.valueExpression = valueExpression
        self.assertExpression = assertExpression
        self.isFlexible = isFlexible
        self.shouldIfNotExists = shouldIfNotExists
    }

    // MARK: - Builder Methods

    /// Sets the field type.
    ///
    /// - Parameter type: The field type to set.
    /// - Returns: A new builder with the field type set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("age", on: "users")
    ///     .type(.int)
    ///     .execute()
    /// ```
    public func type(_ type: FieldType) -> FieldDefinitionBuilder {
        FieldDefinitionBuilder(
            client: client,
            fieldName: fieldName,
            tableName: tableName,
            fieldType: type,
            defaultValue: defaultValue,
            valueExpression: valueExpression,
            assertExpression: assertExpression,
            isFlexible: isFlexible,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Sets a default value for the field.
    ///
    /// - Parameter value: The default value expression.
    /// - Returns: A new builder with the default value set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("created_at", on: "users")
    ///     .type(.datetime)
    ///     .default("time::now()")
    ///     .execute()
    /// ```
    public func `default`(_ value: String) -> FieldDefinitionBuilder {
        FieldDefinitionBuilder(
            client: client,
            fieldName: fieldName,
            tableName: tableName,
            fieldType: fieldType,
            defaultValue: value,
            valueExpression: valueExpression,
            assertExpression: assertExpression,
            isFlexible: isFlexible,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Sets a value expression for the field (computed field).
    ///
    /// - Parameter expression: The value expression.
    /// - Returns: A new builder with the value expression set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("full_name", on: "users")
    ///     .type(.string)
    ///     .value("string::concat($this.first_name, ' ', $this.last_name)")
    ///     .execute()
    /// ```
    public func value(_ expression: String) -> FieldDefinitionBuilder {
        FieldDefinitionBuilder(
            client: client,
            fieldName: fieldName,
            tableName: tableName,
            fieldType: fieldType,
            defaultValue: defaultValue,
            valueExpression: expression,
            assertExpression: assertExpression,
            isFlexible: isFlexible,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Sets an assertion (validation rule) for the field.
    ///
    /// - Parameter expression: The assertion expression.
    /// - Returns: A new builder with the assertion set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("age", on: "users")
    ///     .type(.int)
    ///     .assert("$value >= 0 AND $value <= 150")
    ///     .execute()
    /// ```
    public func assert(_ expression: String) -> FieldDefinitionBuilder {
        FieldDefinitionBuilder(
            client: client,
            fieldName: fieldName,
            tableName: tableName,
            fieldType: fieldType,
            defaultValue: defaultValue,
            valueExpression: valueExpression,
            assertExpression: expression,
            isFlexible: isFlexible,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Marks the field as flexible (allows nested fields).
    ///
    /// - Returns: A new builder with flexible set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("metadata", on: "users")
    ///     .type(.object)
    ///     .flexible()
    ///     .execute()
    /// ```
    public func flexible() -> FieldDefinitionBuilder {
        FieldDefinitionBuilder(
            client: client,
            fieldName: fieldName,
            tableName: tableName,
            fieldType: fieldType,
            defaultValue: defaultValue,
            valueExpression: valueExpression,
            assertExpression: assertExpression,
            isFlexible: true,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Adds IF NOT EXISTS clause to the definition.
    ///
    /// - Returns: A new builder with IF NOT EXISTS set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("email", on: "users")
    ///     .type(.string)
    ///     .ifNotExists()
    ///     .execute()
    /// ```
    public func ifNotExists() -> FieldDefinitionBuilder {
        FieldDefinitionBuilder(
            client: client,
            fieldName: fieldName,
            tableName: tableName,
            fieldType: fieldType,
            defaultValue: defaultValue,
            valueExpression: valueExpression,
            assertExpression: assertExpression,
            isFlexible: isFlexible,
            shouldIfNotExists: true
        )
    }

    // MARK: - Execution

    /// Generates the SurrealQL statement for this field definition.
    ///
    /// - Returns: A SurrealQL statement string.
    /// - Throws: `SurrealError.schemaValidation` if validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let builder = db.schema.defineField("email", on: "users").type(.string)
    /// let sql = try builder.toSurrealQL()
    /// // Returns: "DEFINE FIELD email ON TABLE users TYPE string"
    /// ```
    public func toSurrealQL() throws -> String {
        // Validate names
        try SurrealValidator.validateFieldName(fieldName)
        try SurrealValidator.validateTableName(tableName)

        // Generate DEFINE FIELD statement
        var parts: [String] = ["DEFINE FIELD"]

        if shouldIfNotExists {
            parts.append("IF NOT EXISTS")
        }

        parts.append(fieldName)
        parts.append("ON TABLE")
        parts.append(tableName)

        // Add type
        if let type = fieldType {
            parts.append("TYPE")
            parts.append(type.toSurrealQL())
        }

        // Add default value
        if let defaultVal = defaultValue {
            parts.append("DEFAULT")
            parts.append(defaultVal)
        }

        // Add value expression
        if let valueExpr = valueExpression {
            parts.append("VALUE")
            parts.append(valueExpr)
        }

        // Add assertion
        if let assertExpr = assertExpression {
            parts.append("ASSERT")
            parts.append(assertExpr)
        }

        // Add flexible flag
        if isFlexible {
            parts.append("FLEXIBLE")
        }

        return parts.joined(separator: " ")
    }

    /// Executes the field definition on the database.
    ///
    /// - Returns: The result of the query execution.
    /// - Throws: `SurrealError` if the query fails or validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("email", on: "users")
    ///     .type(.string)
    ///     .execute()
    /// ```
    @discardableResult
    public func execute() async throws -> SurrealValue {
        let sql = try toSurrealQL()
        let results = try await client.query(sql)
        return results.first ?? .null
    }
}
