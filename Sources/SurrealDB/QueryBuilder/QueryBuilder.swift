import Foundation

/// A fluent query builder for SurrealQL.
///
/// The query builder provides a type-safe, ergonomic way to construct SurrealQL queries
/// with automatic parameter binding to prevent SQL injection.
///
/// Example:
/// ```swift
/// let users: [User] = try await db
///     .query()
///     .select("name", "email")
///     .from("users")
///     .where(field: "age", op: .greaterThanOrEqual, value: .int(18))
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
    ///
    /// - Parameter fields: Field names to select. Use "*" or pass no arguments to select all fields.
    /// - Returns: A new QueryBuilder with the SELECT clause added.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if any field name is invalid.
    public func select(_ fields: String...) throws(SurrealError) -> QueryBuilder {
        for field in fields where field != "*" {
            try SurrealValidator.validateFieldName(field)
        }
        let fieldsStr = fields.isEmpty ? "*" : fields.joined(separator: ", ")
        return updated(query: "SELECT \(fieldsStr)")
    }

    /// Specifies the table to select from.
    ///
    /// - Parameter table: The table name.
    /// - Returns: A new QueryBuilder with the FROM clause added.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if the table name is invalid.
    public func from(_ table: String) throws(SurrealError) -> QueryBuilder {
        try SurrealValidator.validateTableName(table)
        return updated(query: query + " FROM \(table)")
    }

    /// Specifies a record ID to select from.
    public func from(_ recordId: RecordID) -> QueryBuilder {
        return updated(query: query + " FROM \(recordId.toString())")
    }

    /// Type-safe WHERE clause with parameter binding.
    ///
    /// This method automatically parameterizes values to prevent SQL injection.
    ///
    /// - Parameters:
    ///   - field: The field name to filter on. Must be a valid identifier.
    ///   - op: The comparison operator to use.
    ///   - value: The value to compare against. Automatically parameterized.
    /// - Returns: A new QueryBuilder with the WHERE clause added.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if the field name is invalid.
    ///
    /// - Note: Multiple calls to `where()` or `whereRaw()` will add additional WHERE clauses
    ///   to the query. For multiple conditions, use `whereRaw()` with logical operators (AND/OR).
    ///
    /// Example:
    /// ```swift
    /// let adults = try await db.query()
    ///     .select("name")
    ///     .from("users")
    ///     .where(field: "age", op: .greaterThanOrEqual, value: .int(18))
    ///     .fetch()
    /// ```
    public func `where`(field: String, op: ComparisonOperator, value: SurrealValue) throws(SurrealError) -> QueryBuilder {
        try SurrealValidator.validateFieldName(field)
        let binding = IDGenerator.generateBindingID()
        var newBindings = bindings
        newBindings[binding] = value
        return QueryBuilder(
            client: client,
            query: query + " WHERE \(field) \(op.rawValue) $\(binding)",
            bindings: newBindings
        )
    }

    /// For complex conditions, use raw query with explicit variables.
    ///
    /// - Parameters:
    ///   - condition: The WHERE condition string. Can reference variables using $name syntax.
    ///   - variables: Dictionary of variable names to values.
    /// - Returns: A new QueryBuilder with the WHERE clause added.
    ///
    /// Example:
    /// ```swift
    /// let results = try await db.query()
    ///     .select("*")
    ///     .from("users")
    ///     .whereRaw("age >= $minAge AND status = $status", variables: [
    ///         "minAge": .int(18),
    ///         "status": .string("active")
    ///     ])
    ///     .fetch()
    /// ```
    public func whereRaw(_ condition: String, variables: [String: SurrealValue] = [:]) -> QueryBuilder {
        var newBindings = bindings
        for (key, value) in variables {
            newBindings[key] = value
        }
        return QueryBuilder(
            client: client,
            query: query + " WHERE \(condition)",
            bindings: newBindings
        )
    }

    /// Adds an ORDER BY clause.
    ///
    /// - Parameters:
    ///   - field: The field name to order by.
    ///   - ascending: Whether to order ascending (default: true) or descending.
    /// - Returns: A new QueryBuilder with the ORDER BY clause added.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if the field name is invalid.
    public func orderBy(_ field: String, ascending: Bool = true) throws(SurrealError) -> QueryBuilder {
        try SurrealValidator.validateFieldName(field)
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
    ///
    /// - Parameter fields: Field names to group by.
    /// - Returns: A new QueryBuilder with the GROUP BY clause added.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if any field name is invalid.
    public func groupBy(_ fields: String...) throws(SurrealError) -> QueryBuilder {
        for field in fields {
            try SurrealValidator.validateFieldName(field)
        }
        let fieldsStr = fields.joined(separator: ", ")
        return updated(query: query + " GROUP BY \(fieldsStr)")
    }

    // MARK: - CREATE

    /// Starts a CREATE query.
    ///
    /// - Parameter table: The table name.
    /// - Returns: A new QueryBuilder with the CREATE clause.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if the table name is invalid.
    public func create(_ table: String) throws(SurrealError) -> QueryBuilder {
        try SurrealValidator.validateTableName(table)
        return updated(query: "CREATE \(table)")
    }

    /// Sets content for CREATE or UPDATE.
    ///
    /// - Parameter data: The data to set as content. Automatically parameterized.
    /// - Returns: A new QueryBuilder with the CONTENT clause.
    /// - Throws: ``SurrealError/encodingError(_:)`` if the data cannot be encoded.
    public func content<T: Encodable>(_ data: T) throws(SurrealError) -> QueryBuilder {
        let value = try SurrealValue.encode(data)
        let binding = IDGenerator.generateBindingID()
        var newBindings = bindings
        newBindings[binding] = value
        return QueryBuilder(
            client: client,
            query: query + " CONTENT $\(binding)",
            bindings: newBindings
        )
    }

    /// Sets a field value.
    ///
    /// - Parameters:
    ///   - field: The field name to set.
    ///   - value: The value to set. Automatically parameterized.
    /// - Returns: A new QueryBuilder with the SET clause.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if the field name is invalid.
    public func set(_ field: String, to value: SurrealValue) throws(SurrealError) -> QueryBuilder {
        try SurrealValidator.validateFieldName(field)
        let binding = IDGenerator.generateBindingID()
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
    ///
    /// - Parameter target: The table name or record ID.
    /// - Returns: A new QueryBuilder with the UPDATE clause.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if the target is invalid.
    public func update(_ target: String) throws(SurrealError) -> QueryBuilder {
        try SurrealValidator.validateTableName(target)
        return updated(query: "UPDATE \(target)")
    }

    // MARK: - DELETE

    /// Starts a DELETE query.
    ///
    /// - Parameter target: The table name or record ID.
    /// - Returns: A new QueryBuilder with the DELETE clause.
    /// - Throws: ``SurrealError/invalidQuery(_:)`` if the target is invalid.
    public func delete(_ target: String) throws(SurrealError) -> QueryBuilder {
        try SurrealValidator.validateTableName(target)
        return updated(query: "DELETE FROM \(target)")
    }

    // MARK: - RELATE

    /// Creates a RELATE query.
    public func relate(_ from: RecordID, to: RecordID, via table: String) -> QueryBuilder {
        return updated(query: "RELATE \(from.toString())->\(table)->\(to.toString())")
    }

    // MARK: - Execute

    /// Executes the query and returns raw SurrealValue results.
    public func execute() async throws(SurrealError) -> [SurrealValue] {
        try await client.query(query, variables: bindings.isEmpty ? nil : bindings)
    }

    /// Executes the query and decodes the results to the specified type.
    public func fetch<T: Decodable>() async throws(SurrealError) -> [T] {
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
                var decoded: [T] = []
                for item in array {
                    decoded.append(try item.safelyDecode())
                }
                return decoded
            } else {
                // Single result
                return [try resultValue.safelyDecode()]
            }
        }

        // Fallback: try to decode directly
        if case .array(let array) = firstResult {
            var decoded: [T] = []
            for item in array {
                decoded.append(try item.safelyDecode())
            }
            return decoded
        } else {
            return [try firstResult.safelyDecode()]
        }
    }

    /// Executes the query and returns the first result, or nil if no results.
    public func fetchOne<T: Decodable>() async throws(SurrealError) -> T? {
        let results: [T] = try await fetch()
        return results.first
    }

    // MARK: - Private

    private func updated(query: String) -> QueryBuilder {
        QueryBuilder(client: client, query: query, bindings: bindings)
    }
}

// MARK: - ComparisonOperator

/// Comparison operators for type-safe WHERE clauses.
///
/// Use these operators with the `where(field:op:value:)` method to build secure,
/// parameterized WHERE conditions.
///
/// Example:
/// ```swift
/// let adults = try await db.query()
///     .select("*")
///     .from("users")
///     .where(field: "age", op: .greaterThanOrEqual, value: .int(18))
///     .fetch()
/// ```
public enum ComparisonOperator: String, Sendable {
    /// Equal to (`=`)
    case equal = "="

    /// Not equal to (`!=`)
    case notEqual = "!="

    /// Greater than (`>`)
    case greaterThan = ">"

    /// Greater than or equal to (`>=`)
    case greaterThanOrEqual = ">="

    /// Less than (`<`)
    case lessThan = "<"

    /// Less than or equal to (`<=`)
    case lessThanOrEqual = "<="

    /// In a set of values (`IN`)
    case `in` = "IN"

    /// Not in a set of values (`NOT IN`)
    case notIn = "NOT IN"

    /// Contains a value (`CONTAINS`)
    case contains = "CONTAINS"

    /// Pattern matching (`~`)
    case like = "~"
}

// MARK: - SurrealDB Extension

extension SurrealDB {
    /// Creates a new query builder.
    public func query() -> QueryBuilder {
        QueryBuilder(client: self)
    }
}
