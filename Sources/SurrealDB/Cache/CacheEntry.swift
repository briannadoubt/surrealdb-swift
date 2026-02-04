import Foundation

/// A cached value with metadata for TTL and LRU tracking.
///
/// Each cache entry stores the cached `SurrealValue` along with the set of
/// database tables it depends on (for invalidation) and access metadata
/// (for LRU eviction).
public struct CacheEntry: Sendable {
    /// The cached value.
    public let value: SurrealValue

    /// The tables this entry is associated with, for invalidation.
    public let tables: Set<String>

    /// When this entry was created.
    public let createdAt: Date

    /// When this entry was last accessed.
    public internal(set) var lastAccessedAt: Date

    /// How many times this entry has been accessed from the cache.
    public internal(set) var accessCount: Int

    /// The time-to-live for this specific entry. `nil` means no expiration.
    public let ttl: TimeInterval?

    /// Whether this entry has expired based on its TTL.
    public var isExpired: Bool {
        guard let ttl else { return false }
        return Date().timeIntervalSince(createdAt) > ttl
    }

    /// Creates a new cache entry.
    ///
    /// - Parameters:
    ///   - value: The value to cache.
    ///   - tables: The set of tables this entry depends on.
    ///   - ttl: Optional TTL override for this entry.
    public init(
        value: SurrealValue,
        tables: Set<String>,
        ttl: TimeInterval? = nil
    ) {
        self.value = value
        self.tables = tables
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.accessCount = 0
        self.ttl = ttl
    }

    /// Restores a cache entry from persistent storage with all fields.
    ///
    /// Used by persistent ``CacheStorage`` implementations (e.g., `GRDBCacheStorage`)
    /// to reconstruct entries with their original timestamps and access counts.
    public init(
        value: SurrealValue,
        tables: Set<String>,
        createdAt: Date,
        lastAccessedAt: Date,
        accessCount: Int,
        ttl: TimeInterval?
    ) {
        self.value = value
        self.tables = tables
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.ttl = ttl
    }
}
