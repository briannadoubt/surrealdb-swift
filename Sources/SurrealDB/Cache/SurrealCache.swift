import Foundation

/// Client-side cache coordinator for SurrealDB query results.
///
/// `SurrealCache` manages cached query results with support for:
/// - **TTL** (time-to-live) expiration
/// - **LRU** (least recently used) eviction
/// - **Table-based invalidation** (including from live query notifications)
/// - **Pluggable storage backends** via ``CacheStorage``
///
/// The cache operates at the ``SurrealValue`` level, caching raw RPC results
/// before they are decoded to user types. This allows a single cache entry
/// to serve multiple decode targets.
///
/// ## Automatic Invalidation
///
/// When a mutation operation (create, update, delete, etc.) is performed,
/// all cache entries associated with the affected table are automatically
/// invalidated. When live queries are active, notifications from the server
/// also trigger invalidation.
///
/// ## Manual Invalidation
///
/// ```swift
/// // Invalidate a specific table
/// await db.invalidateCache(table: "users")
///
/// // Clear the entire cache
/// await db.invalidateCache()
/// ```
public actor SurrealCache {
    private let storage: any CacheStorage
    private let policy: CachePolicy

    /// Creates a new cache coordinator.
    ///
    /// - Parameters:
    ///   - storage: The storage backend to use.
    ///   - policy: The cache policy controlling TTL, eviction, and behavior.
    public init(storage: any CacheStorage, policy: CachePolicy) {
        self.storage = storage
        self.policy = policy
    }

    /// The cache policy in use.
    public var cachePolicy: CachePolicy {
        policy
    }

    /// Retrieves a cached value for the given key.
    ///
    /// Returns `nil` if the key is not in the cache or has expired.
    ///
    /// - Parameter key: The cache key to look up.
    /// - Returns: The cached value, or `nil`.
    public func get(_ key: CacheKey) async -> SurrealValue? {
        guard let entry = await storage.get(key) else { return nil }

        if entry.isExpired {
            await storage.remove(key)
            return nil
        }

        return entry.value
    }

    /// Stores a value in the cache.
    ///
    /// If the cache is at capacity, entries will be evicted according to
    /// the configured eviction strategy before the new entry is stored.
    ///
    /// - Parameters:
    ///   - key: The cache key.
    ///   - value: The value to cache.
    ///   - tables: The set of tables this value depends on.
    ///   - ttl: Optional TTL override. If `nil`, uses the policy's default TTL.
    public func set(
        _ key: CacheKey,
        value: SurrealValue,
        tables: Set<String>,
        ttl: TimeInterval? = nil
    ) async {
        let effectiveTTL = ttl ?? policy.defaultTTL
        let entry = CacheEntry(value: value, tables: tables, ttl: effectiveTTL)

        // Evict if necessary before inserting
        if let maxEntries = policy.maxEntries {
            let currentCount = await storage.count
            if currentCount >= maxEntries {
                await evict(count: max(1, maxEntries / 10))
            }
        }

        await storage.set(key, entry: entry)
    }

    /// Invalidates all cache entries associated with the given table.
    ///
    /// - Parameter table: The table name whose cache entries should be removed.
    public func invalidate(table: String) async {
        await storage.removeEntries(forTable: table)
    }

    /// Invalidates all cache entries.
    public func invalidateAll() async {
        await storage.removeAll()
    }

    /// Returns statistics about the current cache state.
    public func stats() async -> CacheStats {
        let entries = await storage.allEntries()
        let expiredCount = entries.filter { $0.entry.isExpired }.count

        return CacheStats(
            totalEntries: entries.count,
            expiredEntries: expiredCount,
            tables: Set(entries.flatMap { $0.entry.tables }),
            oldestEntry: entries.min(by: { $0.entry.createdAt < $1.entry.createdAt })?.entry.createdAt,
            newestEntry: entries.max(by: { $0.entry.createdAt < $1.entry.createdAt })?.entry.createdAt
        )
    }

    /// Evicts entries based on the configured eviction strategy.
    private func evict(count: Int) async {
        switch policy.evictionStrategy {
        case .lru:
            await evictLRU(count: count)
        }
    }

    /// Evicts the least recently used entries.
    private func evictLRU(count: Int) async {
        let allEntries = await storage.allEntries()

        // First, remove expired entries
        for entry in allEntries where entry.entry.isExpired {
            await storage.remove(entry.key)
        }

        // If we still need to evict more, remove by LRU order (oldest access first)
        let remaining = await storage.count
        if let maxEntries = policy.maxEntries, remaining >= maxEntries {
            let nonExpired = allEntries.filter { !$0.entry.isExpired }
            let toEvict = nonExpired.prefix(count)
            for entry in toEvict {
                await storage.remove(entry.key)
            }
        }
    }
}

/// Statistics about the current cache state.
public struct CacheStats: Sendable {
    /// Total number of entries in the cache.
    public let totalEntries: Int

    /// Number of expired entries awaiting cleanup.
    public let expiredEntries: Int

    /// Set of table names with cached data.
    public let tables: Set<String>

    /// Timestamp of the oldest cache entry.
    public let oldestEntry: Date?

    /// Timestamp of the newest cache entry.
    public let newestEntry: Date?
}
