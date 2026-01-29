import Foundation

/// A fluent query builder for SurrealQL.
///
/// The query builder provides a type-safe, ergonomic way to construct SurrealQL queries.
///
/// Example:
/// ```swift
/// let users: [User] = try await db
///     .query()
///     .select("name", "email")
///     .from("users")
///     .where("age >= 18")
///     .orderBy("name")
///     .limit(10)
///     .fetch()
/// ```
public struct QueryBuilder: Sendable {
    private let client: SurrealDB
    private var query: String
    private var bindings: [String: SurrealValue]

    init(client: SurrealDB) {
        self.client = client
        self.query = ""
        self.bindings = [:]
    }

    private init(client: SurrealDB, query: String, bindings: [String: SurrealValue]) {
        self.client = client
        self.query = query
        self.bindings = bindings
    }

    // MARK: - SELECT

    /// Starts a SELECT query.
    public func select(_ fields: String...) -> QueryBuilder {
        let fieldsStr = fields.isEmpty ? "*" : fields.joined(separator: ", ")
        return updated(query: "SELECT \(fieldsStr)")
    }

    /// Specifies the table to select from.
    public func from(_ table: String) -> QueryBuilder {
        return updated(query: query + " FROM \(table)")
    }

    /// Specifies a record ID to select from.
    public func from(_ recordId: RecordID) -> QueryBuilder {
        return updated(query: query + " FROM \(recordId.toString())")
    }

    /// Adds a WHERE clause.
    public func `where`(_ condition: String) -> QueryBuilder {
        return updated(query: query + " WHERE \(condition)")
    }

    /// Adds an ORDER BY clause.
    public func orderBy(_ field: String, ascending: Bool = true) -> QueryBuilder {
        let direction = ascending ? "ASC" : "DESC"
        return updated(query: query + " ORDER BY \(field) \(direction)")
    }

    /// Adds a LIMIT clause.
    public func limit(_ count: Int) -> QueryBuilder {
        return updated(query: query + " LIMIT \(count)")
    }

    /// Adds a START clause (offset).
    public func start(_ offset: Int) -> QueryBuilder {
        return updated(query: query + " START \(offset)")
    }

    /// Adds a GROUP BY clause.
    public func groupBy(_ fields: String...) -> QueryBuilder {
        let fieldsStr = fields.joined(separator: ", ")
        return updated(query: query + " GROUP BY \(fieldsStr)")
    }

    // MARK: - CREATE

    /// Starts a CREATE query.
    public func create(_ table: String) -> QueryBuilder {
        return updated(query: "CREATE \(table)")
    }

    /// Sets content for CREATE or UPDATE.
    public func content<T: Encodable>(_ data: T) throws -> QueryBuilder {
        let value = try SurrealValue(from: data)
        let binding = "content_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        var newBindings = bindings
        newBindings[binding] = value
        return QueryBuilder(
            client: client,
            query: query + " CONTENT $\(binding)",
            bindings: newBindings
        )
    }

    /// Sets a field value.
    public func set(_ field: String, to value: SurrealValue) -> QueryBuilder {
        let binding = "value_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        var newBindings = bindings
        newBindings[binding] = value

        let setClause = query.contains(" SET ") ? ", \(field) = $\(binding)" : " SET \(field) = $\(binding)"
        return QueryBuilder(
            client: client,
            query: query + setClause,
            bindings: newBindings
        )
    }

    // MARK: - UPDATE

    /// Starts an UPDATE query.
    public func update(_ target: String) -> QueryBuilder {
        return updated(query: "UPDATE \(target)")
    }

    // MARK: - DELETE

    /// Starts a DELETE query.
    public func delete(_ target: String) -> QueryBuilder {
        return updated(query: "DELETE FROM \(target)")
    }

    // MARK: - RELATE

    /// Creates a RELATE query.
    public func relate(_ from: RecordID, to: RecordID, via table: String) -> QueryBuilder {
        return updated(query: "RELATE \(from.toString())->\(table)->\(to.toString())")
    }

    // MARK: - Execute

    /// Executes the query and returns raw SurrealValue results.
    public func execute() async throws -> [SurrealValue] {
        try await client.query(query, variables: bindings.isEmpty ? nil : bindings)
    }

    /// Executes the query and decodes the results to the specified type.
    public func fetch<T: Decodable>() async throws -> [T] {
        let results = try await execute()

        // Results from the query method are wrapped in a result object
        // We need to extract the actual data
        guard let firstResult = results.first else {
            return []
        }

        // The result structure is typically { "status": "OK", "result": [...] }
        if case .object(let obj) = firstResult,
           let resultValue = obj["result"] {
            if case .array(let array) = resultValue {
                return try array.map { try $0.decode() }
            } else {
                // Single result
                return [try resultValue.decode()]
            }
        }

        // Fallback: try to decode directly
        if case .array(let array) = firstResult {
            return try array.map { try $0.decode() }
        } else {
            return [try firstResult.decode()]
        }
    }

    /// Executes the query and returns the first result, or nil if no results.
    public func fetchOne<T: Decodable>() async throws -> T? {
        let results: [T] = try await fetch()
        return results.first
    }

    // MARK: - Private

    private func updated(query: String) -> QueryBuilder {
        QueryBuilder(client: client, query: query, bindings: bindings)
    }
}

// MARK: - SurrealDB Extension

extension SurrealDB {
    /// Creates a new query builder.
    public func query() -> QueryBuilder {
        QueryBuilder(client: self)
    }
}
