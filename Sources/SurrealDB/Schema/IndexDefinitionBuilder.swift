import Foundation

/// A builder for defining table indexes with a fluent API.
///
/// This builder provides a type-safe, chainable interface for creating index definitions
/// in SurrealDB. It supports standard, unique, full-text, and search indexes.
///
/// ## Example
///
/// ```swift
/// // Define a unique index
/// try await db.schema
///     .defineIndex("unique_email", on: "users")
///     .fields("email")
///     .unique()
///     .execute()
///
/// // Define a full-text search index
/// try await db.schema
///     .defineIndex("search_content", on: "posts")
///     .fields("title", "body")
///     .search(analyzer: "ascii")
///     .execute()
/// ```
public struct IndexDefinitionBuilder: Sendable {
    private let client: SurrealDB
    private let indexName: String
    private let tableName: String
    private let indexFields: [String]
    private let indexType: IndexType
    private let shouldIfNotExists: Bool

    /// Creates a new index definition builder.
    ///
    /// - Parameters:
    ///   - client: The SurrealDB client to use for execution.
    ///   - indexName: The name of the index to define.
    ///   - tableName: The name of the table containing this index.
    internal init(
        client: SurrealDB,
        indexName: String,
        tableName: String,
        indexFields: [String] = [],
        indexType: IndexType = .standard,
        shouldIfNotExists: Bool = false
    ) {
        self.client = client
        self.indexName = indexName
        self.tableName = tableName
        self.indexFields = indexFields
        self.indexType = indexType
        self.shouldIfNotExists = shouldIfNotExists
    }

    /// Creates a new index definition builder with StaticString parameters.
    ///
    /// - Parameters:
    ///   - client: The SurrealDB client to use for execution.
    ///   - indexName: The name of the index to define.
    ///   - tableName: The name of the table containing this index.
    internal init(
        client: SurrealDB,
        indexName: StaticString,
        tableName: StaticString,
        indexFields: [String] = [],
        indexType: IndexType = .standard,
        shouldIfNotExists: Bool = false
    ) {
        self.init(
            client: client,
            indexName: String(describing: indexName),
            tableName: String(describing: tableName),
            indexFields: indexFields,
            indexType: indexType,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    // MARK: - Builder Methods

    /// Sets the fields to index.
    ///
    /// - Parameter fields: The field names to index.
    /// - Returns: A new builder with the fields set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineIndex("idx_name", on: "users")
    ///     .fields("first_name", "last_name")
    ///     .execute()
    /// ```
    public func fields(_ fields: StaticString...) -> IndexDefinitionBuilder {
        self.fields(fields.map { String(describing: $0) })
    }

    /// Sets the fields to index using an array.
    ///
    /// - Parameter fields: The field names to index.
    /// - Returns: A new builder with the fields set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let fieldNames = ["first_name", "last_name"]
    /// try await db.schema
    ///     .defineIndex("idx_name", on: "users")
    ///     .fields(fieldNames)
    ///     .execute()
    /// ```
    public func fields(_ fields: [String]) -> IndexDefinitionBuilder {
        IndexDefinitionBuilder(
            client: client,
            indexName: indexName,
            tableName: tableName,
            indexFields: fields,
            indexType: indexType,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Sets the fields to index using an array of StaticStrings.
    ///
    /// - Parameter fields: The field names to index.
    /// - Returns: A new builder with the fields set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let fieldNames: [StaticString] = ["first_name", "last_name"]
    /// try await db.schema
    ///     .defineIndex("idx_name", on: "users")
    ///     .fields(fieldNames)
    ///     .execute()
    /// ```
    public func fields(_ fields: [StaticString]) -> IndexDefinitionBuilder {
        self.fields(fields.map { String(describing: $0) })
    }

    /// Makes the index unique.
    ///
    /// - Returns: A new builder with unique index type set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineIndex("unique_username", on: "users")
    ///     .fields("username")
    ///     .unique()
    ///     .execute()
    /// ```
    public func unique() -> IndexDefinitionBuilder {
        IndexDefinitionBuilder(
            client: client,
            indexName: indexName,
            tableName: tableName,
            indexFields: indexFields,
            indexType: .unique,
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Creates a full-text search index with BM25 ranking.
    ///
    /// - Warning: The analyzer name is interpolated directly into SQL. Never use untrusted
    ///   user input as analyzer names as this could lead to SQL injection vulnerabilities.
    ///   Only use hardcoded analyzer names or thoroughly validated input.
    ///
    /// - Parameter analyzer: Optional analyzer name (defaults to "LIKE").
    /// - Returns: A new builder with full-text search type set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineIndex("ft_content", on: "posts")
    ///     .fields("content")
    ///     .fulltext(analyzer: "ascii")
    ///     .execute()
    /// ```
    public func fulltext(analyzer: String? = nil) -> IndexDefinitionBuilder {
        IndexDefinitionBuilder(
            client: client,
            indexName: indexName,
            tableName: tableName,
            indexFields: indexFields,
            indexType: .fulltext(analyzer: analyzer),
            shouldIfNotExists: shouldIfNotExists
        )
    }

    /// Creates a search index for advanced text search.
    ///
    /// - Warning: The analyzer name is interpolated directly into SQL. Never use untrusted
    ///   user input as analyzer names as this could lead to SQL injection vulnerabilities.
    ///   Only use hardcoded analyzer names or thoroughly validated input.
    ///
    /// - Parameter analyzer: Optional analyzer name (defaults to "LIKE").
    /// - Returns: A new builder with search index type set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try await db.schema
    ///     .defineIndex("search_title", on: "posts")
    ///     .fields("title")
    ///     .search(analyzer: "ascii")
    ///     .execute()
    /// ```
    public func search(analyzer: String? = nil) -> IndexDefinitionBuilder {
        IndexDefinitionBuilder(
            client: client,
            indexName: indexName,
            tableName: tableName,
            indexFields: indexFields,
            indexType: .search(analyzer: analyzer),
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
    ///     .defineIndex("idx_email", on: "users")
    ///     .fields("email")
    ///     .ifNotExists()
    ///     .execute()
    /// ```
    public func ifNotExists() -> IndexDefinitionBuilder {
        IndexDefinitionBuilder(
            client: client,
            indexName: indexName,
            tableName: tableName,
            indexFields: indexFields,
            indexType: indexType,
            shouldIfNotExists: true
        )
    }

    // MARK: - Execution

    /// Generates the SurrealQL statement for this index definition.
    ///
    /// - Returns: A SurrealQL statement string.
    /// - Throws: `SurrealError.schemaValidation` if validation fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let builder = db.schema
    ///     .defineIndex("unique_email", on: "users")
    ///     .fields("email")
    ///     .unique()
    /// let sql = try builder.toSurrealQL()
    /// // Returns: "DEFINE INDEX unique_email ON TABLE users FIELDS email UNIQUE"
    /// ```
    public func toSurrealQL() throws -> String {
        // Validate names
        try SurrealValidator.validateIndexName(indexName)
        try SurrealValidator.validateTableName(tableName)
        try SurrealValidator.validateIndexFields(indexFields)

        // Generate DEFINE INDEX statement
        var parts: [String] = ["DEFINE INDEX"]

        if shouldIfNotExists {
            parts.append("IF NOT EXISTS")
        }

        parts.append(indexName)
        parts.append("ON TABLE")
        parts.append(tableName)

        // Add fields
        parts.append("FIELDS")
        parts.append(indexFields.joined(separator: ", "))

        // Add index type
        let typeSQL = indexType.toSurrealQL()
        if !typeSQL.isEmpty {
            parts.append(typeSQL)
        }

        return parts.joined(separator: " ")
    }

    /// Executes the index definition on the database.
    ///
    /// - Returns: The result of the query execution.
    /// - Throws: `SurrealError` if the query fails or validation fails.
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
    @discardableResult
    public func execute() async throws -> SurrealValue {
        let sql = try toSurrealQL()
        let results = try await client.query(sql)
        return results.first ?? .null
    }
}
