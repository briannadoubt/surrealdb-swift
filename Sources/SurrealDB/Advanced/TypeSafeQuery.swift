import Foundation

// MARK: - Type-Safe Query Extension

extension SurrealDB {
    /// Execute a type-safe query for a specific model
    /// - Note: PartialKeyPath parameters are not Sendable, but this is safe because they are
    ///   immediately converted to Strings within this method and never escape.
    nonisolated public func query<T: SurrealModel>(
        _ type: T.Type,
        select fields: [PartialKeyPath<T>]? = nil,
        where predicates: [Predicate] = [],
        orderBy: [(keyPath: PartialKeyPath<T>, ascending: Bool)] = [],
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [T] {
        var queryParts: [String] = []

        // SELECT
        if let fields = fields, !fields.isEmpty {
            let fieldNames = fields.map { extractFieldName(from: $0) }
            queryParts.append("SELECT \(fieldNames.joined(separator: ", "))")
        } else {
            queryParts.append("SELECT *")
        }

        // FROM
        queryParts.append("FROM \(T.tableName)")

        // WHERE
        if !predicates.isEmpty {
            let conditions = predicates.map { $0.toSurrealQL() }
            queryParts.append("WHERE \(conditions.joined(separator: " AND "))")
        }

        // ORDER BY
        if !orderBy.isEmpty {
            let orders = orderBy.map { (keyPath, ascending) in
                let field = extractFieldName(from: keyPath)
                return "\(field) \(ascending ? "ASC" : "DESC")"
            }
            queryParts.append("ORDER BY \(orders.joined(separator: ", "))")
        }

        // LIMIT
        if let limit = limit {
            queryParts.append("LIMIT \(limit)")
        }

        // OFFSET
        if let offset = offset {
            queryParts.append("START \(offset)")
        }

        let query = queryParts.joined(separator: " ")
        let results = try await self.query(query)

        // Extract and decode results
        guard let firstResult = results.first else {
            return []
        }

        if case .array(let array) = firstResult {
            return try array.map { try $0.decode() }
        } else if case .object(let obj) = firstResult, let result = obj["result"] {
            if case .array(let array) = result {
                return try array.map { try $0.decode() }
            }
        }

        return try [firstResult.decode()]
    }

    /// Create a record for a model type
    nonisolated public func create<T: SurrealModel>(_ model: T) async throws -> T {
        return try await create(T.tableName, data: model)
    }

    /// Update a model
    nonisolated public func update<T: SurrealModel>(_ model: T) async throws -> T {
        guard let id = model.id else {
            throw SurrealError.invalidRecordID("Model must have an ID to update")
        }
        return try await update(id.toString(), data: model)
    }

    /// Delete a model
    nonisolated public func delete<T: SurrealModel>(_ model: T) async throws {
        guard let id = model.id else {
            throw SurrealError.invalidRecordID("Model must have an ID to delete")
        }
        try await delete(id.toString())
    }
}

// MARK: - Fluent Type-Safe API

/// A type-safe query builder
/// Note: This struct is not Sendable because PartialKeyPath is not Sendable in Swift.
/// However, since it's used synchronously to build queries before passing to async functions,
/// this is safe. The actual query execution is Sendable.
public struct TypeSafeQuery<T: SurrealModel> {
    private let db: SurrealDB
    private var selectFields: [PartialKeyPath<T>]?
    private var predicates: [Predicate] = []
    private var orderFields: [(keyPath: PartialKeyPath<T>, ascending: Bool)] = []
    private var limitValue: Int?
    private var offsetValue: Int?
    private var includeRelations: [PartialKeyPath<T>] = []

    init(db: SurrealDB) {
        self.db = db
    }

    /// Select specific fields
    public func select(_ fields: PartialKeyPath<T>...) -> TypeSafeQuery<T> {
        var copy = self
        copy.selectFields = fields
        return copy
    }

    /// Add a WHERE predicate
    public func `where`(_ predicate: Predicate) -> TypeSafeQuery<T> {
        var copy = self
        copy.predicates.append(predicate)
        return copy
    }

    /// Add multiple WHERE predicates
    public func `where`(_ predicates: Predicate...) -> TypeSafeQuery<T> {
        var copy = self
        copy.predicates.append(contentsOf: predicates)
        return copy
    }

    /// Add ORDER BY
    public func orderBy(_ keyPath: PartialKeyPath<T>, ascending: Bool = true) -> TypeSafeQuery<T> {
        var copy = self
        copy.orderFields.append((keyPath, ascending))
        return copy
    }

    /// Add LIMIT
    public func limit(_ value: Int) -> TypeSafeQuery<T> {
        var copy = self
        copy.limitValue = value
        return copy
    }

    /// Add OFFSET
    public func offset(_ value: Int) -> TypeSafeQuery<T> {
        var copy = self
        copy.offsetValue = value
        return copy
    }

    /// Include a relationship
    public func including(_ keyPath: PartialKeyPath<T>) -> TypeSafeQuery<T> {
        var copy = self
        copy.includeRelations.append(keyPath)
        return copy
    }

    /// Execute the query
    public func fetch() async throws -> [T] {
        // Note: PartialKeyPath is not Sendable, but since we're only passing immutable
        // value types across the actor boundary and they don't escape, this is safe.
        // The values are immediately converted to strings within the actor method.
        let fields = selectFields
        let preds = predicates
        let orders = orderFields
        let lim = limitValue
        let off = offsetValue

        return try await db.query(
            T.self,
            select: fields,
            where: preds,
            orderBy: orders,
            limit: lim,
            offset: off
        )
    }

    /// Fetch the first result
    public func fetchOne() async throws -> T? {
        try await fetch().first
    }
}

// MARK: - SurrealDB Extension

extension SurrealDB {
    /// Create a type-safe query for a model
    nonisolated public func query<T: SurrealModel>(_ type: T.Type) -> TypeSafeQuery<T> {
        TypeSafeQuery<T>(db: self)
    }
}

// MARK: - Example Usage (commented out)

/*
// Define models
struct User: SurrealModel {
    @ID var id: RecordID?
    var name: String
    var email: String
    var age: Int

    @Relation(edge: Authored.self)
    var posts: [Post]
}

struct Post: SurrealModel {
    @ID var id: RecordID?
    var title: String
    var content: String

    @Relation(edge: Authored.self, direction: .in)
    var author: User
}

struct Authored: EdgeModel {
    typealias From = User
    typealias To = Post
    var publishedAt: Date
}

// Usage
let adults = try await db.query(User.self)
    .where(\User.age >= 18)
    .where(\User.email != "")
    .orderBy(\User.name)
    .limit(10)
    .fetch()

// Create with relationships
let user = User(id: nil, name: "John", email: "john@example.com", age: 30)
let savedUser = try await db.create(user)

let post = Post(id: nil, title: "Hello", content: "World")
let savedPost = try await db.create(post)

try await savedUser.relate(
    to: savedPost,
    via: Authored(publishedAt: Date()),
    using: db
)

// Load relationships
let posts = try await savedUser.load(\.posts, using: db)
*/
