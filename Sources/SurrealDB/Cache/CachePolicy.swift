import Foundation

/// Configuration for the client-side cache.
///
/// Controls TTL (time-to-live), maximum entry count, eviction strategy,
/// and live query invalidation behavior.
///
/// Example:
/// ```swift
/// let db = try SurrealDB(
///     url: "ws://localhost:8000/rpc",
///     cachePolicy: .default
/// )
/// ```
public struct CachePolicy: Sendable {
    /// Default time-to-live for cache entries in seconds. `nil` means entries don't expire.
    public var defaultTTL: TimeInterval?

    /// Maximum number of cache entries. `nil` means unlimited.
    public var maxEntries: Int?

    /// The eviction strategy when the cache is full.
    public var evictionStrategy: EvictionStrategy

    /// Whether to automatically invalidate cache entries when live query
    /// notifications are received for affected tables.
    public var invalidateOnLiveQuery: Bool

    /// The eviction strategy for the cache.
    public enum EvictionStrategy: Sendable {
        /// Least Recently Used - evicts entries that were accessed least recently.
        case lru
    }

    /// Creates a new cache policy.
    ///
    /// - Parameters:
    ///   - defaultTTL: Default time-to-live in seconds. Defaults to 300 (5 minutes).
    ///   - maxEntries: Maximum number of entries. Defaults to 1000.
    ///   - evictionStrategy: Eviction strategy. Defaults to `.lru`.
    ///   - invalidateOnLiveQuery: Whether to invalidate on live query notifications. Defaults to `true`.
    public init(
        defaultTTL: TimeInterval? = 300,
        maxEntries: Int? = 1000,
        evictionStrategy: EvictionStrategy = .lru,
        invalidateOnLiveQuery: Bool = true
    ) {
        self.defaultTTL = defaultTTL
        self.maxEntries = maxEntries
        self.evictionStrategy = evictionStrategy
        self.invalidateOnLiveQuery = invalidateOnLiveQuery
    }

    /// Default cache policy with 5-minute TTL, 1000 max entries, and LRU eviction.
    public static let `default` = CachePolicy()

    /// Aggressive caching with 30-minute TTL and 5000 max entries.
    public static let aggressive = CachePolicy(
        defaultTTL: 1800,
        maxEntries: 5000
    )

    /// Short-lived cache with 30-second TTL and 100 max entries.
    public static let shortLived = CachePolicy(
        defaultTTL: 30,
        maxEntries: 100
    )
}
