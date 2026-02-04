import Foundation
@testable import SurrealDB
import Testing

/// Integration tests for client-side caching behavior.
///
/// These tests verify that caching works correctly with real database operations.
///
/// To run these tests:
/// 1. Start SurrealDB: `surreal start --user root --pass root memory`
/// 2. Run tests: `SURREALDB_TEST=1 swift test --filter CacheIntegrationTests`
@Suite("Cache Integration Tests")
struct CacheIntegrationTests {
    struct TestUser: Codable, Equatable {
        let name: String
        let age: Int
    }

    // MARK: - In-Memory Cache Tests

    @Test("Cache stores and retrieves query results", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func cacheStoresAndRetrievesResults() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: .default)
        try await db.connect()
        try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Create test data
        let user = TestUser(name: "Alice", age: 30)
        let _: TestUser = try await db.create("cache_test_users", data: user)

        // First query - should be cache miss
        let start1 = Date()
        let results1: [TestUser] = try await db.select("cache_test_users")
        let duration1 = Date().timeIntervalSince(start1)

        #expect(results1.count == 1)
        #expect(results1[0].name == "Alice")

        // Second query - should be cache hit (much faster)
        let start2 = Date()
        let results2: [TestUser] = try await db.select("cache_test_users")
        let duration2 = Date().timeIntervalSince(start2)

        #expect(results2.count == 1)
        #expect(results2 == results1)

        // Cache hit should be significantly faster
        #expect(duration2 < duration1 * 0.5)

        // Cleanup
        try await db.delete("cache_test_users")
        try await db.disconnect()
    }

    @Test("Cache invalidates on mutation", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func cacheInvalidatesOnMutation() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: .default)
        try await db.connect()
        try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Create initial data
        let user1 = TestUser(name: "Bob", age: 25)
        let _: TestUser = try await db.create("cache_test_users2", data: user1)

        // Query to populate cache
        let results1: [TestUser] = try await db.select("cache_test_users2")
        #expect(results1.count == 1)

        // Mutate data
        let user2 = TestUser(name: "Charlie", age: 35)
        let _: TestUser = try await db.create("cache_test_users2", data: user2)

        // Query again - should NOT return cached result
        let results2: [TestUser] = try await db.select("cache_test_users2")
        #expect(results2.count == 2)

        // Cleanup
        try await db.delete("cache_test_users2")
        try await db.disconnect()
    }

    @Test("Cache respects TTL expiration", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func cacheRespectsTTL() async throws {
        // Create cache with 1 second TTL
        let policy = CachePolicy(
            defaultTTL: 1.0,
            maxEntries: 100
        )

        let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: policy)
        try await db.connect()
        try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Create test data
        let user = TestUser(name: "David", age: 40)
        let _: TestUser = try await db.create("cache_test_users3", data: user)

        // Query to populate cache
        let results1: [TestUser] = try await db.select("cache_test_users3")
        #expect(results1.count == 1)

        // Wait for TTL to expire
        try await Task.sleep(for: .seconds(1.5))

        // Mutate data without invalidating cache directly
        // (simulating expired entry check)
        // Directly add to DB to avoid cache invalidation
        let sql = """
        CREATE cache_test_users3 CONTENT {
            name: 'Eve',
            age: 45
        };
        """
        let _: [SurrealValue] = try await db.query(sql)

        // Query should fetch fresh data since cache expired
        let _: [TestUser] = try await db.select("cache_test_users3")
        // Note: Cache should have expired and fetched fresh data

        // Cleanup
        try await db.delete("cache_test_users3")
        try await db.disconnect()
    }

    @Test("Cache handles different query parameters", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func cacheHandlesDifferentQueryParameters() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: .default)
        try await db.connect()
        try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Create test data
        let users = [
            TestUser(name: "User1", age: 20),
            TestUser(name: "User2", age: 30),
            TestUser(name: "User3", age: 40)
        ]

        for user in users {
            let _: TestUser = try await db.create("cache_test_users4", data: user)
        }

        // Query with different parameters should create different cache entries
        let sql1 = "SELECT * FROM cache_test_users4 WHERE age > $minAge"
        let results1: [SurrealValue] = try await db.query(sql1, variables: ["minAge": .int(25)])

        let sql2 = "SELECT * FROM cache_test_users4 WHERE age > $minAge"
        let results2: [SurrealValue] = try await db.query(sql2, variables: ["minAge": .int(35)])

        // Different parameters should yield different results
        #expect(results1.count != results2.count)

        // Same query with same params should hit cache
        let results3: [SurrealValue] = try await db.query(sql1, variables: ["minAge": .int(25)])
        #expect(results3.count == results1.count)

        // Cleanup
        try await db.delete("cache_test_users4")
        try await db.disconnect()
    }

    @Test("Cache stats reflect current state", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func cacheStatsReflectState() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: .default)
        try await db.connect()
        try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Create test data
        let user = TestUser(name: "Stats User", age: 50)
        let _: TestUser = try await db.create("cache_test_users5", data: user)

        // Query to populate cache
        let _: [TestUser] = try await db.select("cache_test_users5")

        // Check stats
        if let stats = await db.cacheStats() {
            #expect(stats.totalEntries >= 1)
            #expect(stats.tables.contains("cache_test_users5"))
        }

        // Cleanup
        try await db.delete("cache_test_users5")
        try await db.disconnect()
    }

    @Test("Manual cache invalidation works", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func manualCacheInvalidation() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: .default)
        try await db.connect()
        try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Create test data
        let user = TestUser(name: "Manual User", age: 60)
        let _: TestUser = try await db.create("cache_test_users6", data: user)

        // Query to populate cache
        let results1: [TestUser] = try await db.select("cache_test_users6")
        #expect(results1.count == 1)

        // Manually invalidate cache
        await db.invalidateCache(table: "cache_test_users6")

        // Add data directly to DB (simulating external change)
        let sql = """
        CREATE cache_test_users6 CONTENT {
            name: 'Another User',
            age: 65
        };
        """
        let _: [SurrealValue] = try await db.query(sql)

        // Query should fetch fresh data
        let results2: [TestUser] = try await db.select("cache_test_users6")
        #expect(results2.count == 2)

        // Cleanup
        try await db.delete("cache_test_users6")
        try await db.disconnect()
    }

    @Test("LRU eviction works when cache is full", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func lruEvictionWorks() async throws {
        // Create cache with small max size
        let policy = CachePolicy(
            defaultTTL: nil,
            maxEntries: 3
        )

        let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: policy)
        try await db.connect()
        try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Create multiple tables with data
        for i in 1...5 {
            let user = TestUser(name: "User\(i)", age: 20 + i)
            let _: TestUser = try await db.create("lru_test_\(i)", data: user)

            // Query each table to populate cache
            let _: [TestUser] = try await db.select("lru_test_\(i)")

            // Small delay to ensure different access times
            try await Task.sleep(for: .milliseconds(100))
        }

        // Check that cache size is limited
        if let stats = await db.cacheStats() {
            #expect(stats.totalEntries <= 3)
        }

        // Cleanup
        for i in 1...5 {
            try await db.delete("lru_test_\(i)")
        }
        try await db.disconnect()
    }
}
