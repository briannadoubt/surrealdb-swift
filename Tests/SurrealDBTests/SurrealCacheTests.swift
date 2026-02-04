import Foundation
@testable import SurrealDB
import Testing

// MARK: - SurrealCache Tests

@Suite("SurrealCache Tests")
struct SurrealCacheTests {
    @Test("Get and set basic flow")
    func getSetBasicFlow() async {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        let key = CacheKey.select("users")
        let value: SurrealValue = .array([
            .object(["name": .string("Alice")]),
            .object(["name": .string("Bob")])
        ])

        await cache.set(key, value: value, tables: ["users"])

        let retrieved = await cache.get(key)
        #expect(retrieved == value)
    }

    @Test("Get returns nil for missing key")
    func getMissingKey() async {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        let result = await cache.get(CacheKey.select("nonexistent"))
        #expect(result == nil)
    }

    @Test("TTL enforcement via policy default")
    func ttlEnforcementViaPolicy() async throws {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: 0.1, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        let key = CacheKey.select("users")
        await cache.set(key, value: .string("data"), tables: ["users"])

        // Should be accessible immediately
        let immediate = await cache.get(key)
        #expect(immediate == .string("data"))

        // Wait for TTL to expire
        try await Task.sleep(for: .milliseconds(150))

        // Should be nil after expiration
        let expired = await cache.get(key)
        #expect(expired == nil)
    }

    @Test("TTL override per entry")
    func ttlOverridePerEntry() async throws {
        let storage = InMemoryCacheStorage()
        // Policy has long default TTL
        let policy = CachePolicy(defaultTTL: 3600, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        // Set entry with short TTL override
        let key = CacheKey.select("temp")
        await cache.set(key, value: .string("temporary"), tables: ["temp"], ttl: 0.1)

        // Should be accessible immediately
        let immediate = await cache.get(key)
        #expect(immediate == .string("temporary"))

        // Wait for the entry-specific TTL to expire
        try await Task.sleep(for: .milliseconds(150))

        // Should be nil after expiration
        let expired = await cache.get(key)
        #expect(expired == nil)
    }

    @Test("Table-based invalidation")
    func tableBasedInvalidation() async {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        let usersKey = CacheKey.select("users")
        let postsKey = CacheKey.select("posts")
        let joinKey = CacheKey.query("SELECT * FROM users JOIN posts")

        await cache.set(usersKey, value: .string("users"), tables: ["users"])
        await cache.set(postsKey, value: .string("posts"), tables: ["posts"])
        await cache.set(joinKey, value: .string("joined"), tables: ["users", "posts"])

        // Invalidate "users" table
        await cache.invalidate(table: "users")

        // Users entry should be gone
        #expect(await cache.get(usersKey) == nil)

        // Posts entry should remain
        #expect(await cache.get(postsKey) == .string("posts"))

        // Join entry should be gone (it depends on "users")
        #expect(await cache.get(joinKey) == nil)
    }

    @Test("Invalidate all entries")
    func invalidateAll() async {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        await cache.set(CacheKey.select("users"), value: .string("users"), tables: ["users"])
        await cache.set(CacheKey.select("posts"), value: .string("posts"), tables: ["posts"])
        await cache.set(CacheKey.select("comments"), value: .string("comments"), tables: ["comments"])

        await cache.invalidateAll()

        #expect(await cache.get(CacheKey.select("users")) == nil)
        #expect(await cache.get(CacheKey.select("posts")) == nil)
        #expect(await cache.get(CacheKey.select("comments")) == nil)
    }

    @Test("LRU eviction when maxEntries exceeded")
    func lruEviction() async throws {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: 3)
        let cache = SurrealCache(storage: storage, policy: policy)

        // Fill the cache to capacity
        await cache.set(CacheKey.select("a"), value: .string("a"), tables: ["a"])
        try await Task.sleep(for: .milliseconds(10))
        await cache.set(CacheKey.select("b"), value: .string("b"), tables: ["b"])
        try await Task.sleep(for: .milliseconds(10))
        await cache.set(CacheKey.select("c"), value: .string("c"), tables: ["c"])

        // Access "a" to make it recently used
        try await Task.sleep(for: .milliseconds(10))
        _ = await cache.get(CacheKey.select("a"))

        // Adding a fourth entry should trigger eviction
        try await Task.sleep(for: .milliseconds(10))
        await cache.set(CacheKey.select("d"), value: .string("d"), tables: ["d"])

        // "d" should be present (just added)
        #expect(await cache.get(CacheKey.select("d")) == .string("d"))

        // "a" should still be present (recently accessed)
        #expect(await cache.get(CacheKey.select("a")) == .string("a"))

        // "b" should have been evicted (least recently used)
        // Note: eviction removes max(1, maxEntries/10) entries which is 1 for maxEntries=3
        // The LRU order before eviction was: b, c, a (b is oldest access)
        #expect(await cache.get(CacheKey.select("b")) == nil)
    }

    @Test("Cache stats with entries")
    func cacheStats() async throws {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        await cache.set(CacheKey.select("users"), value: .string("users"), tables: ["users"])

        try await Task.sleep(for: .milliseconds(10))

        await cache.set(CacheKey.select("posts"), value: .string("posts"), tables: ["posts"])

        let stats = await cache.stats()

        #expect(stats.totalEntries == 2)
        #expect(stats.expiredEntries == 0)
        #expect(stats.tables == Set(["users", "posts"]))
        #expect(stats.oldestEntry != nil)
        #expect(stats.newestEntry != nil)

        if let oldest = stats.oldestEntry, let newest = stats.newestEntry {
            #expect(oldest <= newest)
        }
    }

    @Test("Cache stats with expired entries")
    func cacheStatsWithExpired() async throws {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        // One normal entry
        await cache.set(CacheKey.select("users"), value: .string("users"), tables: ["users"])

        // One entry with short TTL
        await cache.set(CacheKey.select("temp"), value: .string("temp"), tables: ["temp"], ttl: 0.1)

        // Wait for the short-lived entry to expire
        try await Task.sleep(for: .milliseconds(150))

        let stats = await cache.stats()

        #expect(stats.totalEntries == 2)
        #expect(stats.expiredEntries == 1)
    }

    @Test("Cache stats when empty")
    func cacheStatsEmpty() async {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        let stats = await cache.stats()

        #expect(stats.totalEntries == 0)
        #expect(stats.expiredEntries == 0)
        #expect(stats.tables.isEmpty)
        #expect(stats.oldestEntry == nil)
        #expect(stats.newestEntry == nil)
    }

    @Test("Cache policy is accessible")
    func cachePolicyAccessible() async {
        let policy = CachePolicy(
            defaultTTL: 120,
            maxEntries: 500,
            evictionStrategy: .lru,
            invalidateOnLiveQuery: false
        )
        let cache = SurrealCache(storage: InMemoryCacheStorage(), policy: policy)

        let retrievedPolicy = await cache.cachePolicy

        #expect(retrievedPolicy.defaultTTL == 120)
        #expect(retrievedPolicy.maxEntries == 500)
        #expect(retrievedPolicy.invalidateOnLiveQuery == false)
    }

    @Test("Policy defaultTTL is used when no per-entry TTL")
    func policyDefaultTTLUsed() async throws {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: 0.1, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        let key = CacheKey.select("users")
        // No TTL override -- should use the policy's defaultTTL of 0.1s
        await cache.set(key, value: .string("data"), tables: ["users"])

        #expect(await cache.get(key) == .string("data"))

        try await Task.sleep(for: .milliseconds(150))

        #expect(await cache.get(key) == nil)
    }

    @Test("Nil policy defaultTTL means no expiration")
    func nilPolicyTTLMeansNoExpiration() async throws {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        let key = CacheKey.select("persistent")
        await cache.set(key, value: .string("forever"), tables: ["persistent"])

        // Sleep a bit to prove it doesn't expire
        try await Task.sleep(for: .milliseconds(50))

        #expect(await cache.get(key) == .string("forever"))
    }

    @Test("Multiple tables in stats")
    func multipleTablesInStats() async {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        await cache.set(
            CacheKey.query("SELECT * FROM users, posts, comments"),
            value: .null,
            tables: ["users", "posts", "comments"]
        )

        let stats = await cache.stats()
        #expect(stats.tables == Set(["users", "posts", "comments"]))
    }

    @Test("Invalidating a table that has no entries is a no-op")
    func invalidateNonexistentTable() async {
        let storage = InMemoryCacheStorage()
        let policy = CachePolicy(defaultTTL: nil, maxEntries: nil)
        let cache = SurrealCache(storage: storage, policy: policy)

        await cache.set(CacheKey.select("users"), value: .string("data"), tables: ["users"])

        // Invalidating a table with no associated entries should not affect anything
        await cache.invalidate(table: "nonexistent")

        #expect(await cache.get(CacheKey.select("users")) == .string("data"))
    }
}
