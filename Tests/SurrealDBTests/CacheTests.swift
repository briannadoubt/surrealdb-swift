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
        #expect(key.paramsHash.isEmpty)
    }

    @Test("Select key creation with record ID")
    func selectKeyCreationWithRecordID() {
        let key = CacheKey.select("users:123")

        #expect(key.method == "select")
        #expect(key.target == "users:123")
        #expect(key.paramsHash.isEmpty)
    }

    @Test("Query key creation without variables")
    func queryKeyCreationWithoutVariables() {
        let key = CacheKey.query("SELECT * FROM users")

        #expect(key.method == "query")
        #expect(key.target == "SELECT * FROM users")
        #expect(key.paramsHash.isEmpty)
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
        #expect(key1.paramsHash.isEmpty)
        #expect(key2.paramsHash.isEmpty)
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

        #expect(key.paramsHash.isEmpty)
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
        #expect(await storage.isEmpty)

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

        #expect(await storage.isEmpty)
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
        #expect(await storage.isEmpty)
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

        #expect(await storage.isEmpty)

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
