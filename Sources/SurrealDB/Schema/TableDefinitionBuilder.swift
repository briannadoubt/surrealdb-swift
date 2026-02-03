import Foundation

/// A builder for defining database tables with a fluent API.
///
/// This builder provides a type-safe, chainable interface for creating table definitions
/// in SurrealDB. It supports schema modes, table types (including relations), and various
/// configuration options.
///
/// ## Example
///
/// ```swift
/// // Define a standard table
/// try await db.schema
///     .defineTable("users")
///     .schemafull()
///     .ifNotExists()
///     .execute()
///
/// // Define a relation table
/// try await db.schema
///     .defineTable("follows")
///     .relation(from: "users", to: "users")
///     .execute()
/// ```
public struct TableDefinitionBuilder: Sendable {
    private let client: SurrealDB
    private let tableName: String
    private let schemaMode: SchemaMode?
    private let tableType: TableType?
    private let shouldDrop: Bool
    private let shouldIfNotExists: Bool

    /// Creates a new table definition builder.
    ///
    /// - Parameters:
    ///   - client: The SurrealDB client to use for execution.
    ///   - tableName: The name of the table to define.
    internal init(
        client: SurrealDB,
        tableName: String,
        schemaMode: SchemaMode? = nil,
        tableType: TableType? = nil,
        shouldDrop: Bool = false,
        shouldIfNotExists: Bool = false
    ) {
        self.client = client
        self.tableName = tableName
        self.schemaMode = schemaMode
        self.tableType = tableType
        self.shouldDrop = shouldDrop
        self.shouldIfNotExists = shouldIfNotExists
    }

    // MARK: - Builder Methods

    /// Sets the table to be schemafull (only accept defined fields).
    ///
    /// - Returns: A new builder with the schemafull mode set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineTable("users")
    ///     .schemafull()
    ///     .execute()
    /// ```
    public func schemafull() -> TableDefinitionBuilder {
        TableDefinitionBuilder(
            client: client,
            tableName: tableName,
            schemaMode: .schemafull,
            tableType: tableType,
            shouldDrop: shouldDrop,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Sets the table to be schemaless (accept any fields).
    ///
    /// - Returns: A new builder with the schemaless mode set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineTable("events")
    ///     .schemaless()
    ///     .execute()
    /// ```
    public func schemaless() -> TableDefinitionBuilder {
        TableDefinitionBuilder(
            client: client,
            tableName: tableName,
            schemaMode: .schemaless,
            tableType: tableType,
            shouldDrop: shouldDrop,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Sets the table type to a specific mode.
    ///
    /// - Parameter type: The table type to set.
    /// - Returns: A new builder with the table type set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineTable("likes")
    ///     .type(.relation(from: "users", to: "posts"))
    ///     .execute()
    /// ```
    public func type(_ type: TableType) -> TableDefinitionBuilder {
        TableDefinitionBuilder(
            client: client,
            tableName: tableName,
            schemaMode: schemaMode,
            tableType: type,
            shouldDrop: shouldDrop,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Sets the table as a relation between two tables.
    ///
    /// - Parameters:
    ///   - from: The source table name.
    ///   - to: The target table name.
    /// - Returns: A new builder with the relation type set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineTable("follows")
    ///     .relation(from: "users", to: "users")
    ///     .execute()
    /// ```
    public func relation(from: String, to: String) -> TableDefinitionBuilder {
        TableDefinitionBuilder(
            client: client,
            tableName: tableName,
            schemaMode: schemaMode,
            tableType: .relation(from: from, to: to),
            shouldDrop: shouldDrop,
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
    ///     .defineTable("users")
    ///     .ifNotExists()
    ///     .execute()
    /// ```
    public func ifNotExists() -> TableDefinitionBuilder {
        TableDefinitionBuilder(
            client: client,
            tableName: tableName,
            schemaMode: schemaMode,
            tableType: tableType,
            shouldDrop: shouldDrop,
            shouldIfNotExists: true
        )
    }

    /// Sets the operation to DROP TABLE instead of DEFINE TABLE.
    ///
    /// - Returns: A new builder configured to drop the table.
    ///
    /// ## Note
    ///
    /// This method exists for API consistency with the builder pattern, but you can also
    /// use `SchemaBuilder.removeTable(_:)` directly for a more straightforward approach.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineTable("old_users")
    ///     .drop()
    ///     .execute()
    /// ```
    public func drop() -> TableDefinitionBuilder {
        TableDefinitionBuilder(
            client: client,
            tableName: tableName,
            schemaMode: schemaMode,
            tableType: tableType,
            shouldDrop: true,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    // MARK: - Execution

    /// Generates the SurrealQL statement for this table definition.
    ///
    /// - Returns: A SurrealQL statement string.
    /// - Throws: `SurrealError.schemaValidation` if validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let builder = db.schema.defineTable("users").schemafull()
    /// let sql = try builder.toSurrealQL()
    /// // Returns: "DEFINE TABLE users SCHEMAFULL"
    /// ```
    public func toSurrealQL() throws -> String {
        // Validate table name
        try SurrealValidator.validateTableName(tableName)

        if shouldDrop {
            // Generate DROP TABLE statement
            return "REMOVE TABLE \(tableName)"
        } else {
            // Generate DEFINE TABLE statement
            var parts: [String] = ["DEFINE TABLE"]

            if shouldIfNotExists {
                parts.append("IF NOT EXISTS")
            }

            parts.append(tableName)

            // Add schema mode
            if let mode = schemaMode {
                parts.append(mode.toSurrealQL())
            }

            // Add table type
            if let type = tableType {
                let sql = type.toSurrealQL()
                if !sql.isEmpty {
                    parts.append(sql)
                }
            }

            return parts.joined(separator: " ")
        }
    }

    /// Executes the table definition on the database.
    ///
    /// - Returns: The result of the query execution.
    /// - Throws: `SurrealError` if the query fails or validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineTable("users")
    ///     .schemafull()
    ///     .execute()
    /// ```
    @discardableResult
    public func execute() async throws -> SurrealValue {
        let sql = try toSurrealQL()
        let results = try await client.query(sql)
        return results.first ?? .null
    }
}
