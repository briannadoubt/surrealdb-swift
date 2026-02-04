/// Protocol for cache storage backends.
///
/// Implement this protocol to provide custom storage for the client-side cache.
/// The SDK provides ``InMemoryCacheStorage`` as a default implementation that
/// works on all platforms including WebAssembly.
///
/// For persistent storage on Apple platforms and Linux, use the `SurrealDBGRDB`
/// target which provides a GRDB-backed implementation.
///
/// ## Conformance Requirements
///
/// All implementations must be `Sendable` and safe for concurrent access.
/// The recommended approach is to implement this as an `actor`.
///
/// ## Custom Implementations
///
/// ```swift
/// actor MyCustomStorage: CacheStorage {
///     func get(_ key: CacheKey) async -> CacheEntry? { ... }
///     func set(_ key: CacheKey, entry: CacheEntry) async { ... }
///     // ...
/// }
///
/// let db = try SurrealDB(
///     url: "ws://localhost:8000/rpc",
///     cachePolicy: .default,
///     cacheStorage: MyCustomStorage()
/// )
/// ```
public protocol CacheStorage: Sendable {
    /// Retrieves a cache entry by key.
    ///
    /// Implementations should update access metadata (lastAccessedAt, accessCount)
    /// when returning a hit.
    ///
    /// - Parameter key: The cache key to look up.
    /// - Returns: The cache entry if found, or `nil`.
    func get(_ key: CacheKey) async -> CacheEntry?

    /// Stores a cache entry.
    ///
    /// - Parameters:
    ///   - key: The cache key.
    ///   - entry: The entry to store.
    func set(_ key: CacheKey, entry: CacheEntry) async

    /// Removes a specific cache entry.
    ///
    /// - Parameter key: The cache key to remove.
    func remove(_ key: CacheKey) async

    /// Removes all cache entries.
    func removeAll() async

    /// Removes all entries associated with the specified table.
    ///
    /// - Parameter table: The table name to invalidate.
    func removeEntries(forTable table: String) async

    /// Returns all entries in the cache, ordered by last access time (oldest first).
    ///
    /// This method is used by eviction strategies. Implementations should return
    /// entries sorted by `lastAccessedAt` in ascending order.
    func allEntries() async -> [(key: CacheKey, entry: CacheEntry)]

    /// The number of entries currently in the cache.
    var count: Int { get async }

    /// Whether the cache is empty.
    var isEmpty: Bool { get async }
}
