import Foundation

/// Entry point for building schema definitions with a fluent API.
///
/// This builder provides a type-safe interface for defining tables, fields, and indexes
/// in SurrealDB. It is accessed through the `schema` property on a `SurrealDB` instance.
///
/// ## Example
///
/// ```swift
/// let db = SurrealDB(url: "ws://localhost:8000/rpc")
/// try await db.connect()
/// try await db.use(namespace: "test", database: "test")
///
/// // Define a table
/// try await db.schema
///     .defineTable("users")
///     .schemafull()
///     .execute()
///
/// // Define fields
/// try await db.schema
///     .defineField("email", on: "users")
///     .type(.string)
///     .assert("string::is::email($value)")
///     .execute()
///
/// // Define an index
/// try await db.schema
///     .defineIndex("unique_email", on: "users")
///     .fields("email")
///     .unique()
///     .execute()
/// ```
public struct SchemaBuilder: Sendable {
    private let client: SurrealDB

    /// Creates a new schema builder.
    ///
    /// - Parameter client: The SurrealDB client to use for execution.
    internal init(client: SurrealDB) {
        self.client = client
    }

    // MARK: - Table Definitions

    /// Begins defining a table.
    ///
    /// - Parameter name: The name of the table to define.
    /// - Returns: A table definition builder for chaining.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineTable("users")
    ///     .schemafull()
    ///     .execute()
    /// ```
    public func defineTable(_ name: String) -> TableDefinitionBuilder {
        TableDefinitionBuilder(client: client, tableName: name)
    }

    // MARK: - Field Definitions

    /// Begins defining a field on a table.
    ///
    /// - Parameters:
    ///   - name: The name of the field to define.
    ///   - tableName: The name of the table containing this field.
    /// - Returns: A field definition builder for chaining.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineField("email", on: "users")
    ///     .type(.string)
    ///     .execute()
    /// ```
    public func defineField(_ name: String, on tableName: String) -> FieldDefinitionBuilder {
        FieldDefinitionBuilder(client: client, fieldName: name, tableName: tableName)
    }

    // MARK: - Index Definitions

    /// Begins defining an index on a table.
    ///
    /// - Parameters:
    ///   - name: The name of the index to define.
    ///   - tableName: The name of the table containing this index.
    /// - Returns: An index definition builder for chaining.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineIndex("unique_email", on: "users")
    ///     .fields("email")
    ///     .unique()
    ///     .execute()
    /// ```
    public func defineIndex(_ name: String, on tableName: String) -> IndexDefinitionBuilder {
        IndexDefinitionBuilder(client: client, indexName: name, tableName: tableName)
    }

    // MARK: - Removal Operations

    /// Removes a table from the database.
    ///
    /// - Parameter name: The name of the table to remove.
    /// - Returns: The result of the query execution.
    /// - Throws: `SurrealError` if the query fails or validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema.removeTable("old_users")
    /// ```
    @discardableResult
    public func removeTable(_ name: String) async throws -> SurrealValue {
        try SurrealValidator.validateTableName(name)
        let sql = "REMOVE TABLE \(name)"
        let results = try await client.query(sql)
        return results.first ?? .null
    }

    /// Removes a field from a table.
    ///
    /// - Parameters:
    ///   - name: The name of the field to remove.
    ///   - tableName: The name of the table containing this field.
    /// - Returns: The result of the query execution.
    /// - Throws: `SurrealError` if the query fails or validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema.removeField("old_email", from: "users")
    /// ```
    @discardableResult
    public func removeField(_ name: String, from tableName: String) async throws -> SurrealValue {
        try SurrealValidator.validateFieldName(name)
        try SurrealValidator.validateTableName(tableName)
        let sql = "REMOVE FIELD \(name) ON TABLE \(tableName)"
        let results = try await client.query(sql)
        return results.first ?? .null
    }

    /// Removes an index from a table.
    ///
    /// - Parameters:
    ///   - name: The name of the index to remove.
    ///   - tableName: The name of the table containing this index.
    /// - Returns: The result of the query execution.
    /// - Throws: `SurrealError` if the query fails or validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema.removeIndex("old_idx", from: "users")
    /// ```
    @discardableResult
    public func removeIndex(_ name: String, from tableName: String) async throws -> SurrealValue {
        try SurrealValidator.validateIndexName(name)
        try SurrealValidator.validateTableName(tableName)
        let sql = "REMOVE INDEX \(name) ON TABLE \(tableName)"
        let results = try await client.query(sql)
        return results.first ?? .null
    }

    // MARK: - Info Operations

    /// Gets information about the database schema.
    ///
    /// - Returns: Information about all tables, fields, and indexes in the database.
    /// - Throws: `SurrealError` if the query fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let info = try await db.schema.info()
    /// print(info)
    /// ```
    @discardableResult
    public func info() async throws -> SurrealValue {
        let results = try await client.query("INFO FOR DB")
        return results.first ?? .null
    }

    /// Gets information about a specific table.
    ///
    /// - Parameter name: The name of the table.
    /// - Returns: Information about the table including fields and indexes.
    /// - Throws: `SurrealError` if the query fails or validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let info = try await db.schema.infoForTable("users")
    /// print(info)
    /// ```
    @discardableResult
    public func infoForTable(_ name: String) async throws -> SurrealValue {
        try SurrealValidator.validateTableName(name)
        let results = try await client.query("INFO FOR TABLE \(name)")
        return results.first ?? .null
    }
}
