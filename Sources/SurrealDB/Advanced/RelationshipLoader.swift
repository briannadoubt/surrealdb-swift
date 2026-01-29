import Foundation

/// Actor-based batch relationship loader to solve the N+1 query problem
///
/// Instead of loading relationships one-by-one (N+1 queries), this loader
/// batches multiple relationship loads into a single query, reducing
/// query count by 90%+ in typical scenarios.
///
/// Example: Loading posts for 100 users
/// - Without batching: 101 queries (1 for users + 100 for posts)
/// - With batching: 2 queries (1 for users + 1 batched for all posts)
public actor RelationshipLoader {
    private let db: SurrealDB

    public init(db: SurrealDB) {
        self.db = db
    }

    /// Relationship direction enum (duplicated to avoid needing Edge generic parameter)
    public enum Direction: Sendable {
        case `in`, out, both
    }

    /// Load relationships for multiple source models in a single query
    /// - Parameters:
    ///   - sourceIDs: Array of source record IDs
    ///   - edgeName: The edge table name
    ///   - direction: Relationship direction (.in, .out, or .both)
    ///   - targetTable: The target model table name
    /// - Returns: Dictionary mapping source IDs to arrays of target models
    public func loadBatch<T: SurrealModel>(
        sourceIDs: [RecordID],
        edgeName: String,
        direction: Direction,
        targetTable: String
    ) async throws -> [String: [T]] {
        guard !sourceIDs.isEmpty else {
            return [:]
        }

        // Build the direction operator
        let directionOp: String
        switch direction {
        case .out:
            directionOp = "->"
        case .in:
            directionOp = "<-"
        case .both:
            directionOp = "<->"
        }

        // Build a query that fetches all relationships in one go
        // This uses SurrealDB's graph traversal to efficiently load all edges
        let sourceIDStrings = sourceIDs.map { $0.toString() }
        let sourceIDList = sourceIDStrings.map { "'\($0)'" }.joined(separator: ", ")

        let query = """
        SELECT
            id as source_id,
            \(directionOp)\(edgeName)\(directionOp)\(targetTable) as targets
        FROM [\(sourceIDList)]
        """

        let results = try await db.query(query)

        // Parse results into dictionary
        var grouped: [String: [T]] = [:]

        guard let firstResult = results.first else {
            // No results - return empty dictionary
            return grouped
        }

        // Extract array of results
        let resultArray: [SurrealValue]
        if case .array(let array) = firstResult {
            resultArray = array
        } else if case .object(let obj) = firstResult,
                  let result = obj["result"],
                  case .array(let array) = result {
            resultArray = array
        } else {
            return grouped
        }

        // Process each result row
        for item in resultArray {
            guard case .object(let obj) = item,
                  let sourceID = obj["source_id"],
                  let targets = obj["targets"] else {
                continue
            }

            // Extract source ID string
            let sourceIDString: String
            if case .string(let str) = sourceID {
                sourceIDString = str
            } else {
                continue
            }

            // Decode targets
            let targetModels: [T]
            if case .array(let targetArray) = targets {
                targetModels = try targetArray.compactMap { try? $0.decode() as T }
            } else {
                targetModels = []
            }

            grouped[sourceIDString] = targetModels
        }

        return grouped
    }

    /// Load relationships for a single model (convenience method)
    public func load<T: SurrealModel>(
        sourceID: RecordID,
        edgeName: String,
        direction: Direction,
        targetTable: String
    ) async throws -> [T] {
        let results: [String: [T]] = try await loadBatch(
            sourceIDs: [sourceID],
            edgeName: edgeName,
            direction: direction,
            targetTable: targetTable
        )

        return results[sourceID.toString()] ?? []
    }
}

// MARK: - Convenience Extensions

extension SurrealDB {
    /// Get or create a relationship loader for this database instance
    /// Note: In production, this should be cached per-instance
    nonisolated public var relationshipLoader: RelationshipLoader {
        RelationshipLoader(db: self)
    }
}

extension SurrealModel {
    /// Load relationships for this model using batch loader
    public func loadBatch<Edge: EdgeModel>(
        _ keyPath: KeyPath<Self, Relation<Edge.To, Edge>>,
        using db: SurrealDB
    ) async throws -> [Edge.To] where Edge.From == Self {
        guard let id = self.id else {
            throw SurrealError.invalidRecordID("Model must have an ID")
        }

        let relation = self[keyPath: keyPath]
        let loader = db.relationshipLoader

        // Convert Relation.Direction to RelationshipLoader.Direction
        let loaderDirection: RelationshipLoader.Direction
        switch relation.direction {
        case .in:
            loaderDirection = .in
        case .out:
            loaderDirection = .out
        case .both:
            loaderDirection = .both
        }

        return try await loader.load(
            sourceID: id,
            edgeName: Edge.edgeName,
            direction: loaderDirection,
            targetTable: Edge.To.tableName
        )
    }
}

// MARK: - Batch Loading for Collections

extension Collection where Element: SurrealModel {
    /// Load relationships for all models in this collection with a single query
    /// This is the main N+1 solution - instead of N queries, it makes 1 query.
    ///
    /// Example:
    /// ```swift
    /// let users: [User] = try await db.query(User.self).fetch()
    /// let postsMap = try await users.loadAllRelationships(\.posts, using: db)
    /// ```
    public func loadAllRelationships<Edge: EdgeModel>(
        _ keyPath: KeyPath<Element, Relation<Edge.To, Edge>>,
        using db: SurrealDB
    ) async throws -> [String: [Edge.To]] where Edge.From == Element {
        // Collect all source IDs
        let sourceIDs = compactMap { $0.id }

        guard !sourceIDs.isEmpty else {
            return [:]
        }

        // Get a sample relation to extract metadata
        guard let first = first else {
            return [:]
        }

        let relation = first[keyPath: keyPath]
        let loader = db.relationshipLoader

        // Convert Relation.Direction to RelationshipLoader.Direction
        let loaderDirection: RelationshipLoader.Direction
        switch relation.direction {
        case .in:
            loaderDirection = .in
        case .out:
            loaderDirection = .out
        case .both:
            loaderDirection = .both
        }

        // Load all relationships in a single batch query
        return try await loader.loadBatch(
            sourceIDs: sourceIDs,
            edgeName: Edge.edgeName,
            direction: loaderDirection,
            targetTable: Edge.To.tableName
        )
    }
}
