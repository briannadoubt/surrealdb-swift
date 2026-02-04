/// A key that uniquely identifies a cached query result.
///
/// Cache keys combine the RPC method, target (table or query), and a hash of
/// the parameters to create a unique identifier for each cacheable request.
public struct CacheKey: Hashable, Sendable, Codable {
    /// The RPC method (e.g., "select", "query").
    public let method: String

    /// The target (table name, record ID, or query string).
    public let target: String

    /// A hash of the parameters used in the request.
    public let paramsHash: String

    /// Creates a new cache key.
    ///
    /// - Parameters:
    ///   - method: The RPC method name.
    ///   - target: The target table, record ID, or query string.
    ///   - paramsHash: A hash of the request parameters.
    public init(method: String, target: String, paramsHash: String = "") {
        self.method = method
        self.target = target
        self.paramsHash = paramsHash
    }

    /// Creates a cache key for a select operation.
    ///
    /// - Parameter target: The table name or record ID.
    public static func select(_ target: String) -> CacheKey {
        CacheKey(method: "select", target: target)
    }

    /// Creates a cache key for a query operation.
    ///
    /// - Parameters:
    ///   - sql: The SurrealQL query string.
    ///   - variables: Optional query variables.
    public static func query(_ sql: String, variables: [String: SurrealValue]? = nil) -> CacheKey {
        let hash: String
        if let variables {
            let sorted = variables.sorted { $0.key < $1.key }
            hash = sorted.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        } else {
            hash = ""
        }
        return CacheKey(method: "query", target: sql, paramsHash: hash)
    }

    /// Converts the cache key to a storage key string.
    ///
    /// Used by persistent storage implementations to generate unique keys.
    public func toStorageKey() -> String {
        "\(method):\(target):\(paramsHash)"
    }
}
