import Foundation

/// A fluent API for building graph traversal queries
///
/// Provides type-safe multi-hop graph traversal with depth limiting
/// to prevent infinite loops and excessive database load.
///
/// Example:
/// ```swift
/// // User -> Posts -> Comments (2 hops)
/// let results = try await db.graphQuery(User.self)
///     .traverse(\.posts, depth: 1)
///     .traverse(\.comments, depth: 2)
///     .fetch()
/// ```
public struct GraphQuery<T: SurrealModel> {
    private let db: SurrealDB
    private var startingIDs: [RecordID]
    private var traversals: [TraversalStep] = []
    private var maxDepth: Int = 5
    private var limitValue: Int?

    struct TraversalStep {
        let edgeName: String
        let direction: String  // "->", "<-", or "<->"
        let depth: Int
    }

    init(db: SurrealDB, startingIDs: [RecordID] = []) {
        self.db = db
        self.startingIDs = startingIDs
    }

    /// Start from specific record IDs
    public func from(_ ids: RecordID...) -> GraphQuery<T> {
        var copy = self
        copy.startingIDs = ids
        return copy
    }

    /// Start from an array of IDs
    public func from(_ ids: [RecordID]) -> GraphQuery<T> {
        var copy = self
        copy.startingIDs = ids
        return copy
    }

    /// Traverse an outgoing relationship
    public func traverse<Edge: EdgeModel>(
        _ keyPath: KeyPath<T, Relation<Edge.To, Edge>>,
        depth: Int = 1
    ) -> GraphQuery<T> where Edge.From == T {
        var copy = self
        copy.traversals.append(TraversalStep(
            edgeName: Edge.edgeName,
            direction: "->",
            depth: depth
        ))
        return copy
    }

    /// Traverse an incoming relationship
    public func traverseIncoming<Edge: EdgeModel>(
        _ keyPath: KeyPath<T, Relation<Edge.From, Edge>>,
        depth: Int = 1
    ) -> GraphQuery<T> where Edge.To == T {
        var copy = self
        copy.traversals.append(TraversalStep(
            edgeName: Edge.edgeName,
            direction: "<-",
            depth: depth
        ))
        return copy
    }

    /// Traverse in both directions
    public func traverseBoth(
        edgeName: String,
        depth: Int = 1
    ) -> GraphQuery<T> {
        var copy = self
        copy.traversals.append(TraversalStep(
            edgeName: edgeName,
            direction: "<->",
            depth: depth
        ))
        return copy
    }

    /// Set maximum traversal depth (default: 5)
    public func maxDepth(_ depth: Int) -> GraphQuery<T> {
        var copy = self
        copy.maxDepth = depth
        return copy
    }

    /// Limit the number of results
    public func limit(_ value: Int) -> GraphQuery<T> {
        var copy = self
        copy.limitValue = value
        return copy
    }

    /// Build the SurrealQL query
    func buildQuery() -> String {
        var query = "SELECT * FROM "

        // Starting point
        if startingIDs.isEmpty {
            query += T.tableName
        } else {
            let ids = startingIDs.map { "'\($0.toString())'" }.joined(separator: ", ")
            query += "[\(ids)]"
        }

        // Build traversal path
        for traversal in traversals {
            let depthStr = traversal.depth > 1 ? "...\(traversal.depth)" : ""
            query += "\(traversal.direction)\(traversal.edgeName)\(depthStr)"
        }

        // Add limit if specified
        if let limit = limitValue {
            query += " LIMIT \(limit)"
        }

        return query
    }

    /// Execute the graph query
    public func fetch() async throws(SurrealError) -> [T] {
        let query = buildQuery()
        let results = try await db.query(query)

        guard let firstResult = results.first else {
            return []
        }

        if case .array(let array) = firstResult {
            var decoded: [T] = []
            for item in array {
                decoded.append(try item.safelyDecode())
            }
            return decoded
        } else if case .object(let obj) = firstResult,
                  let result = obj["result"],
                  case .array(let array) = result {
            var decoded: [T] = []
            for item in array {
                decoded.append(try item.safelyDecode())
            }
            return decoded
        }

        return try [firstResult.safelyDecode()]
    }

    /// Execute and return the first result
    public func fetchOne() async throws(SurrealError) -> T? {
        try await fetch().first
    }

    /// Count the results without fetching them
    public func count() async throws(SurrealError) -> Int {
        let query = buildQuery().replacingOccurrences(of: "SELECT *", with: "SELECT count()")
        let results = try await db.query(query)

        guard let firstResult = results.first else {
            return 0
        }

        if case .int(let count) = firstResult {
            return count
        } else if case .object(let obj) = firstResult,
                  let result = obj["result"],
                  case .int(let count) = result {
            return count
        }

        return 0
    }
}

// MARK: - SurrealDB Extension

extension SurrealDB {
    /// Create a graph query starting from a specific model type
    nonisolated public func graphQuery<T: SurrealModel>(_ type: T.Type) -> GraphQuery<T> {
        GraphQuery<T>(db: self)
    }
}

// MARK: - Relationship Counting

extension SurrealModel {
    /// Count related records without loading them
    public func relatedCount<Edge: EdgeModel>(
        _ keyPath: KeyPath<Self, Relation<Edge.To, Edge>>,
        using db: SurrealDB
    ) async throws(SurrealError) -> Int where Edge.From == Self {
        guard let id = self.id else {
            throw SurrealError.invalidRecordID("Model must have an ID")
        }

        let relation = self[keyPath: keyPath]
        let directionOp = relation.direction == .out ? "->" : (relation.direction == .in ? "<-" : "<->")

        let query = """
        SELECT count() FROM \(id.toString())\(directionOp)\(Edge.edgeName)
        """

        let results = try await db.query(query)

        guard let firstResult = results.first else {
            return 0
        }

        if case .int(let count) = firstResult {
            return count
        } else if case .object(let obj) = firstResult,
                  let result = obj["result"],
                  case .int(let count) = result {
            return count
        }

        return 0
    }
}
