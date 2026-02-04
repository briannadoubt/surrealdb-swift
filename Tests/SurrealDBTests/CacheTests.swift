import Foundation
@testable import SurrealDB
import Testing

// MARK: - CacheKey Tests

@Suite("Cache Key Tests")
struct CacheKeyTests {
    @Test("Select key creation")
    func selectKeyCreation() {
        let key = CacheKey.select("users")

        #expect(key.method == "select")
        #expect(key.target == "users")
        #expect(key.paramsHash == "")
    }

    @Test("Select key creation with record ID")
    func selectKeyCreationWithRecordID() {
        let key = CacheKey.select("users:123")

        #expect(key.method == "select")
        #expect(key.target == "users:123")
        #expect(key.paramsHash == "")
    }

    @Test("Query key creation without variables")
    func queryKeyCreationWithoutVariables() {
        let key = CacheKey.query("SELECT * FROM users")

        #expect(key.method == "query")
        #expect(key.target == "SELECT * FROM users")
        #expect(key.paramsHash == "")
    }

    @Test("Query key creation with variables")
    func queryKeyCreationWithVariables() {
        let key = CacheKey.query(
            "SELECT * FROM users WHERE age > $min_age",
            variables: ["min_age": .int(18)]
        )

        #expect(key.method == "query")
        #expect(key.target == "SELECT * FROM users WHERE age > $min_age")
        #expect(key.paramsHash == "min_age=18")
    }

    @Test("Query key with multiple variables is sorted by key name")
    func queryKeyMultipleVariablesSorted() {
        let key = CacheKey.query(
            "SELECT * FROM users WHERE age > $min AND name = $name",
            variables: ["name": .string("John"), "min": .int(18)]
        )

        // Variables should be sorted alphabetically by key
        #expect(key.paramsHash == "min=18&name=\"John\"")
    }

    @Test("Key equality for identical select keys")
    func selectKeyEquality() {
        let key1 = CacheKey.select("users")
        let key2 = CacheKey.select("users")

        #expect(key1 == key2)
    }

    @Test("Key inequality for different select targets")
    func selectKeyInequality() {
        let key1 = CacheKey.select("users")
        let key2 = CacheKey.select("posts")

        #expect(key1 != key2)
    }

    @Test("Key equality for identical query keys")
    func queryKeyEquality() {
        let key1 = CacheKey.query("SELECT * FROM users", variables: ["age": .int(18)])
        let key2 = CacheKey.query("SELECT * FROM users", variables: ["age": .int(18)])

        #expect(key1 == key2)
    }

    @Test("Different variables produce different keys")
    func differentVariablesProduceDifferentKeys() {
        let key1 = CacheKey.query("SELECT * FROM users", variables: ["age": .int(18)])
        let key2 = CacheKey.query("SELECT * FROM users", variables: ["age": .int(21)])

        #expect(key1 != key2)
    }

    @Test("Query key with nil variables differs from empty variables")
    func nilVsNoVariables() {
        let key1 = CacheKey.query("SELECT * FROM users", variables: nil)
        let key2 = CacheKey.query("SELECT * FROM users", variables: [:])

        // Both should have empty paramsHash
        #expect(key1.paramsHash == "")
        #expect(key2.paramsHash == "")
        #expect(key1 == key2)
    }

    @Test("CacheKey is hashable and works in sets")
    func cacheKeyHashable() {
        let key1 = CacheKey.select("users")
        let key2 = CacheKey.select("users")
        let key3 = CacheKey.select("posts")

        var set = Set<CacheKey>()
        set.insert(key1)
        set.insert(key2)
        set.insert(key3)

        #expect(set.count == 2)
    }

    @Test("CacheKey is hashable and works as dictionary keys")
    func cacheKeyAsDictionaryKey() {
        let key1 = CacheKey.select("users")
        let key2 = CacheKey.query("SELECT * FROM users")

        var dict: [CacheKey: String] = [:]
        dict[key1] = "select result"
        dict[key2] = "query result"

        #expect(dict[key1] == "select result")
        #expect(dict[key2] == "query result")
        #expect(dict.count == 2)
    }

    @Test("Select and query keys for the same table are different")
    func selectVsQueryKeyDifference() {
        let selectKey = CacheKey.select("users")
        let queryKey = CacheKey.query("users")

        #expect(selectKey != queryKey)
        #expect(selectKey.method == "select")
        #expect(queryKey.method == "query")
    }

    @Test("Manual CacheKey init")
    func manualInit() {
        let key = CacheKey(method: "custom", target: "something", paramsHash: "abc")

        #expect(key.method == "custom")
        #expect(key.target == "something")
        #expect(key.paramsHash == "abc")
    }

    @Test("Manual CacheKey init with default paramsHash")
    func manualInitDefaultParamsHash() {
        let key = CacheKey(method: "select", target: "users")

        #expect(key.paramsHash == "")
    }
}

// MARK: - CacheEntry Tests

@Suite("Cache Entry Tests")
struct CacheEntryTests {
    @Test("Creation with defaults")
    func creationWithDefaults() {
        let entry = CacheEntry(
            value: .string("test"),
            tables: ["users"]
        )

        #expect(entry.value == .string("test"))
        #expect(entry.tables == Set(["users"]))
        #expect(entry.accessCount == 0)
        #expect(entry.ttl == nil)
        #expect(entry.isExpired == false)
    }

    @Test("Creation with TTL")
    func creationWithTTL() {
        let entry = CacheEntry(
            value: .int(42),
            tables: ["users", "posts"],
            ttl: 60.0
        )

        #expect(entry.value == .int(42))
        #expect(entry.tables == Set(["users", "posts"]))
        #expect(entry.ttl == 60.0)
        #expect(entry.isExpired == false)
    }

    @Test("Entry without TTL never expires")
    func entryWithoutTTLNeverExpires() {
        let entry = CacheEntry(
            value: .string("persistent"),
            tables: ["data"]
        )

        #expect(entry.ttl == nil)
        #expect(entry.isExpired == false)
    }

    @Test("TTL expiration")
    func ttlExpiration() async throws {
        let entry = CacheEntry(
            value: .string("ephemeral"),
            tables: ["temp"],
            ttl: 0.1
        )

        // Entry should not be expired immediately
        #expect(entry.isExpired == false)

        // Wait for the TTL to expire
        try await Task.sleep(for: .milliseconds(150))

        // Now it should be expired
        #expect(entry.isExpired == true)
    }

    @Test("createdAt and lastAccessedAt are set on creation")
    func timestampsOnCreation() {
        let before = Date()
        let entry = CacheEntry(
            value: .null,
            tables: ["test"]
        )
        let after = Date()

        #expect(entry.createdAt >= before)
        #expect(entry.createdAt <= after)
        #expect(entry.lastAccessedAt >= before)
        #expect(entry.lastAccessedAt <= after)
    }

    @Test("Full initializer restores all fields")
    func fullInitializer() {
        let created = Date(timeIntervalSinceReferenceDate: 1000)
        let accessed = Date(timeIntervalSinceReferenceDate: 2000)

        let entry = CacheEntry(
            value: .bool(true),
            tables: ["restored"],
            createdAt: created,
            lastAccessedAt: accessed,
            accessCount: 42,
            ttl: 300.0
        )

        #expect(entry.value == .bool(true))
        #expect(entry.tables == Set(["restored"]))
        #expect(entry.createdAt == created)
        #expect(entry.lastAccessedAt == accessed)
        #expect(entry.accessCount == 42)
        #expect(entry.ttl == 300.0)
    }

    @Test("Multiple tables association")
    func multipleTables() {
        let entry = CacheEntry(
            value: .array([.string("a"), .string("b")]),
            tables: ["users", "posts", "comments"]
        )

        #expect(entry.tables.count == 3)
        #expect(entry.tables.contains("users"))
        #expect(entry.tables.contains("posts"))
        #expect(entry.tables.contains("comments"))
    }

    @Test("Empty tables set")
    func emptyTables() {
        let entry = CacheEntry(
            value: .null,
            tables: []
        )

        #expect(entry.tables.isEmpty)
    }
}

// MARK: - InMemoryCacheStorage Tests

@Suite("In-Memory Cache Storage Tests")
struct InMemoryCacheStorageTests {
    @Test("Set and get basic entry")
    func setAndGet() async {
        let storage = InMemoryCacheStorage()
        let key = CacheKey.select("users")
        let entry = CacheEntry(
            value: .array([.string("Alice"), .string("Bob")]),
            tables: ["users"]
        )

        await storage.set(key, entry: entry)
        let retrieved = await storage.get(key)

        #expect(retrieved != nil)
        #expect(retrieved?.value == .array([.string("Alice"), .string("Bob")]))
    }

    @Test("Get returns nil for missing key")
    func getMissingKey() async {
        let storage = InMemoryCacheStorage()
        let key = CacheKey.select("nonexistent")

        let retrieved = await storage.get(key)

        #expect(retrieved == nil)
    }

    @Test("Remove specific entry")
    func removeEntry() async {
        let storage = InMemoryCacheStorage()
        let key = CacheKey.select("users")
        let entry = CacheEntry(value: .string("data"), tables: ["users"])

        await storage.set(key, entry: entry)
        #expect(await storage.count == 1)

        await storage.remove(key)
        #expect(await storage.count == 0)

        let retrieved = await storage.get(key)
        #expect(retrieved == nil)
    }

    @Test("Remove all entries")
    func removeAll() async {
        let storage = InMemoryCacheStorage()

        await storage.set(
            CacheKey.select("users"),
            entry: CacheEntry(value: .null, tables: ["users"])
        )
        await storage.set(
            CacheKey.select("posts"),
            entry: CacheEntry(value: .null, tables: ["posts"])
        )
        await storage.set(
            CacheKey.select("comments"),
            entry: CacheEntry(value: .null, tables: ["comments"])
        )

        #expect(await storage.count == 3)

        await storage.removeAll()

        #expect(await storage.count == 0)
    }

    @Test("removeEntries(forTable:) removes correct entries")
    func removeEntriesForTable() async {
        let storage = InMemoryCacheStorage()

        // Entry associated with "users" table
        await storage.set(
            CacheKey.select("users"),
            entry: CacheEntry(value: .string("users data"), tables: ["users"])
        )

        // Entry associated with "posts" table
        await storage.set(
            CacheKey.select("posts"),
            entry: CacheEntry(value: .string("posts data"), tables: ["posts"])
        )

        // Entry associated with both "users" and "posts" tables
        await storage.set(
            CacheKey.query("SELECT * FROM users, posts"),
            entry: CacheEntry(value: .string("joined data"), tables: ["users", "posts"])
        )

        #expect(await storage.count == 3)

        // Remove entries for "users" table
        await storage.removeEntries(forTable: "users")

        // The "users" entry and the joint entry should be removed
        #expect(await storage.count == 1)

        // Only "posts" entry remains
        let postsEntry = await storage.get(CacheKey.select("posts"))
        #expect(postsEntry != nil)
        #expect(postsEntry?.value == .string("posts data"))

        // "users" entry is gone
        let usersEntry = await storage.get(CacheKey.select("users"))
        #expect(usersEntry == nil)

        // Joint entry is also gone
        let joinedEntry = await storage.get(CacheKey.query("SELECT * FROM users, posts"))
        #expect(joinedEntry == nil)
    }

    @Test("Expired entries return nil on get")
    func expiredEntriesReturnNil() async throws {
        let storage = InMemoryCacheStorage()
        let key = CacheKey.select("temp")
        let entry = CacheEntry(
            value: .string("temporary"),
            tables: ["temp"],
            ttl: 0.1
        )

        await storage.set(key, entry: entry)

        // Entry should be accessible immediately
        let immediate = await storage.get(key)
        #expect(immediate != nil)

        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))

        // Entry should now return nil and be cleaned up
        let expired = await storage.get(key)
        #expect(expired == nil)

        // Count should reflect the cleanup
        #expect(await storage.count == 0)
    }

    @Test("Access metadata updates on get")
    func accessMetadataUpdates() async throws {
        let storage = InMemoryCacheStorage()
        let key = CacheKey.select("users")
        let entry = CacheEntry(
            value: .string("data"),
            tables: ["users"]
        )

        await storage.set(key, entry: entry)

        // First access
        let first = await storage.get(key)
        #expect(first != nil)
        #expect(first?.accessCount == 1)

        // Small delay to ensure timestamp changes
        try await Task.sleep(for: .milliseconds(10))

        // Second access
        let second = await storage.get(key)
        #expect(second != nil)
        #expect(second?.accessCount == 2)

        // lastAccessedAt should be updated
        if let firstAccess = first?.lastAccessedAt, let secondAccess = second?.lastAccessedAt {
            #expect(secondAccess >= firstAccess)
        }
    }

    @Test("Count reflects current entries")
    func countReflectsCurrentEntries() async {
        let storage = InMemoryCacheStorage()

        #expect(await storage.count == 0)

        await storage.set(
            CacheKey.select("a"),
            entry: CacheEntry(value: .null, tables: ["a"])
        )
        #expect(await storage.count == 1)

        await storage.set(
            CacheKey.select("b"),
            entry: CacheEntry(value: .null, tables: ["b"])
        )
        #expect(await storage.count == 2)

        await storage.remove(CacheKey.select("a"))
        #expect(await storage.count == 1)
    }

    @Test("allEntries returns all stored entries")
    func allEntriesReturnAll() async {
        let storage = InMemoryCacheStorage()

        await storage.set(
            CacheKey.select("users"),
            entry: CacheEntry(value: .string("users"), tables: ["users"])
        )
        await storage.set(
            CacheKey.select("posts"),
            entry: CacheEntry(value: .string("posts"), tables: ["posts"])
        )

        let all = await storage.allEntries()
        #expect(all.count == 2)

        let keys = Set(all.map { $0.key })
        #expect(keys.contains(CacheKey.select("users")))
        #expect(keys.contains(CacheKey.select("posts")))
    }

    @Test("allEntries sorted by lastAccessedAt ascending")
    func allEntriesSortedByAccess() async throws {
        let storage = InMemoryCacheStorage()

        // Insert entries with delays to ensure different lastAccessedAt
        await storage.set(
            CacheKey.select("first"),
            entry: CacheEntry(value: .string("first"), tables: ["first"])
        )

        try await Task.sleep(for: .milliseconds(10))

        await storage.set(
            CacheKey.select("second"),
            entry: CacheEntry(value: .string("second"), tables: ["second"])
        )

        let all = await storage.allEntries()
        #expect(all.count == 2)

        // First inserted should appear first (oldest lastAccessedAt)
        #expect(all[0].key == CacheKey.select("first"))
        #expect(all[1].key == CacheKey.select("second"))
    }

    @Test("Overwriting an entry replaces the value")
    func overwriteEntry() async {
        let storage = InMemoryCacheStorage()
        let key = CacheKey.select("users")

        await storage.set(key, entry: CacheEntry(value: .string("old"), tables: ["users"]))
        await storage.set(key, entry: CacheEntry(value: .string("new"), tables: ["users"]))

        let retrieved = await storage.get(key)
        #expect(retrieved?.value == .string("new"))
        #expect(await storage.count == 1)
    }
}

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

// MARK: - CachePolicy Tests

@Suite("Cache Policy Tests")
struct CachePolicyTests {
    @Test("Default policy values")
    func defaultPolicyValues() {
        let policy = CachePolicy.default

        #expect(policy.defaultTTL == 300)
        #expect(policy.maxEntries == 1000)
        #expect(policy.invalidateOnLiveQuery == true)
    }

    @Test("Aggressive policy values")
    func aggressivePolicyValues() {
        let policy = CachePolicy.aggressive

        #expect(policy.defaultTTL == 1800)
        #expect(policy.maxEntries == 5000)
    }

    @Test("Short-lived policy values")
    func shortLivedPolicyValues() {
        let policy = CachePolicy.shortLived

        #expect(policy.defaultTTL == 30)
        #expect(policy.maxEntries == 100)
    }

    @Test("Custom policy")
    func customPolicy() {
        let policy = CachePolicy(
            defaultTTL: 60,
            maxEntries: 200,
            evictionStrategy: .lru,
            invalidateOnLiveQuery: false
        )

        #expect(policy.defaultTTL == 60)
        #expect(policy.maxEntries == 200)
        #expect(policy.invalidateOnLiveQuery == false)
    }

    @Test("Policy with nil TTL and nil maxEntries")
    func policyWithNilValues() {
        let policy = CachePolicy(
            defaultTTL: nil,
            maxEntries: nil
        )

        #expect(policy.defaultTTL == nil)
        #expect(policy.maxEntries == nil)
    }
}

// MARK: - Table Name Extraction Tests

@Suite("Table Name Extraction Tests")
struct TableNameExtractionTests {
    @Test("extractTableName from plain table name")
    func extractTableNamePlain() {
        let result = SurrealDB.extractTableName(from: "users")
        #expect(result == "users")
    }

    @Test("extractTableName from record ID")
    func extractTableNameFromRecordID() {
        let result = SurrealDB.extractTableName(from: "users:123")
        #expect(result == "users")
    }

    @Test("extractTableName from record ID with string ID")
    func extractTableNameFromStringRecordID() {
        let result = SurrealDB.extractTableName(from: "users:john_doe")
        #expect(result == "users")
    }

    @Test("extractTableName from record ID with complex ID")
    func extractTableNameFromComplexRecordID() {
        let result = SurrealDB.extractTableName(from: "events:2024:01:15")
        #expect(result == "events")
    }

    @Test("extractTableNames from simple SELECT")
    func extractTableNamesFromSimpleSelect() {
        let result = SurrealDB.extractTableNames(from: "SELECT * FROM users")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from SELECT with WHERE clause")
    func extractTableNamesFromSelectWithWhere() {
        let result = SurrealDB.extractTableNames(from: "SELECT * FROM users WHERE age > 18")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from subquery")
    func extractTableNamesFromSubquery() {
        let sql = "SELECT * FROM users WHERE id IN (SELECT id FROM orders)"
        let result = SurrealDB.extractTableNames(from: sql)
        #expect(result == Set(["users", "orders"]))
    }

    @Test("extractTableNames from CREATE statement")
    func extractTableNamesFromCreate() {
        let result = SurrealDB.extractTableNames(from: "CREATE users SET name = 'John'")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from UPDATE statement")
    func extractTableNamesFromUpdate() {
        let result = SurrealDB.extractTableNames(from: "UPDATE users SET active = true")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from DELETE statement")
    func extractTableNamesFromDelete() {
        let result = SurrealDB.extractTableNames(from: "DELETE users WHERE inactive = true")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from INSERT INTO statement")
    func extractTableNamesFromInsertInto() {
        let result = SurrealDB.extractTableNames(from: "INSERT INTO users (name) VALUES ('Alice')")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from UPSERT statement")
    func extractTableNamesFromUpsert() {
        let result = SurrealDB.extractTableNames(from: "UPSERT users SET name = 'John'")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from complex query with multiple tables")
    func extractTableNamesFromComplexQuery() {
        let sql = """
        SELECT * FROM users WHERE id IN (
            SELECT user_id FROM orders WHERE product_id IN (
                SELECT id FROM products
            )
        )
        """
        let result = SurrealDB.extractTableNames(from: sql)
        #expect(result.contains("users"))
        #expect(result.contains("orders"))
        #expect(result.contains("products"))
    }

    @Test("extractTableNames is case insensitive for keywords")
    func extractTableNamesCaseInsensitive() {
        let result1 = SurrealDB.extractTableNames(from: "select * from users")
        let result2 = SurrealDB.extractTableNames(from: "SELECT * FROM users")
        let result3 = SurrealDB.extractTableNames(from: "Select * From users")

        #expect(result1 == Set(["users"]))
        #expect(result2 == Set(["users"]))
        #expect(result3 == Set(["users"]))
    }

    @Test("extractTableNames from query with no recognizable tables")
    func extractTableNamesFromEmptyQuery() {
        let result = SurrealDB.extractTableNames(from: "RETURN 1 + 2")
        #expect(result.isEmpty)
    }

    @Test("extractTableNames with underscored table names")
    func extractTableNamesWithUnderscores() {
        let result = SurrealDB.extractTableNames(from: "SELECT * FROM user_profiles")
        #expect(result == Set(["user_profiles"]))
    }

    @Test("extractTableNames with multiple FROM clauses")
    func extractTableNamesMultipleFromClauses() {
        let sql = "SELECT * FROM users; SELECT * FROM posts"
        let result = SurrealDB.extractTableNames(from: sql)
        #expect(result.contains("users"))
        #expect(result.contains("posts"))
    }
}

// MARK: - CacheStats Tests

@Suite("Cache Stats Tests")
struct CacheStatsTests {
    @Test("CacheStats stores all properties correctly")
    func cacheStatsProperties() {
        let now = Date()
        let earlier = now.addingTimeInterval(-60)

        let stats = CacheStats(
            totalEntries: 10,
            expiredEntries: 2,
            tables: Set(["users", "posts"]),
            oldestEntry: earlier,
            newestEntry: now
        )

        #expect(stats.totalEntries == 10)
        #expect(stats.expiredEntries == 2)
        #expect(stats.tables.count == 2)
        #expect(stats.tables.contains("users"))
        #expect(stats.tables.contains("posts"))
        #expect(stats.oldestEntry == earlier)
        #expect(stats.newestEntry == now)
    }

    @Test("CacheStats with nil dates when empty")
    func cacheStatsEmptyDates() {
        let stats = CacheStats(
            totalEntries: 0,
            expiredEntries: 0,
            tables: [],
            oldestEntry: nil,
            newestEntry: nil
        )

        #expect(stats.totalEntries == 0)
        #expect(stats.oldestEntry == nil)
        #expect(stats.newestEntry == nil)
    }
}
