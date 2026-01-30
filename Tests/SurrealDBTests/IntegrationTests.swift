import Testing
import Foundation
@testable import SurrealDB

/// Integration tests that require a running SurrealDB instance.
///
/// To run these tests:
/// 1. Start SurrealDB: `surreal start --user root --pass root memory`
/// 2. Run tests: `SURREALDB_TEST=1 swift test`
@Suite("Integration Tests")
struct IntegrationTests {

    @Test("Connection test", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testConnection() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        let connected = await db.isConnected
        #expect(connected)

        try await db.disconnect()
    }

    @Test("Ping test", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testPing() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        try await db.ping()

        try await db.disconnect()
    }

    @Test("Version test", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testVersion() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        let version = try await db.version()
        #expect(!version.isEmpty)
        print("SurrealDB version:", version)

        try await db.disconnect()
    }

    @Test("CRUD operations", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testCRUDOperations() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        struct User: Codable {
            let name: String
            let email: String
            let age: Int
        }

        // Create
        let newUser = User(name: "John Doe", email: "john@example.com", age: 30)
        let created: User = try await db.create("users:john", data: newUser)

        #expect(created.name == "John Doe")
        #expect(created.email == "john@example.com")
        #expect(created.age == 30)

        // Read
        let selected: [User] = try await db.select("users:john")
        #expect(selected.first?.name == "John Doe")

        // Update
        let updated: User = try await db.merge("users:john", data: ["age": 31])
        #expect(updated.age == 31)

        // Delete
        try await db.delete("users:john")

        // Verify deletion
        let deleted: [User] = try await db.select("users:john")
        #expect(deleted.isEmpty)

        try await db.disconnect()
    }

    @Test("Query with variables", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testQuery() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        struct TestUser: Codable {
            let name: String
            let age: Int
        }

        // Create some test data
        let users = [
            TestUser(name: "Alice", age: 25),
            TestUser(name: "Bob", age: 35),
            TestUser(name: "Charlie", age: 20)
        ]

        for user in users {
            let userValue = try SurrealValue(from: user)
            _ = try await db.query("CREATE users CONTENT $data", variables: ["data": userValue])
        }

        // Query with filter
        let results = try await db.query(
            "SELECT * FROM users WHERE age >= $minAge ORDER BY age",
            variables: ["minAge": .int(25)]
        )

        #expect(results.count > 0)

        // Cleanup
        try await db.delete("users")

        try await db.disconnect()
    }

    @Test("Live queries", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testLiveQueries() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        let (queryId, stream) = try await db.live("users")

        actor NotificationCollector {
            var notifications: [LiveQueryNotification] = []

            func append(_ notification: LiveQueryNotification) {
                notifications.append(notification)
            }

            func count() -> Int {
                notifications.count
            }

            func actions() -> [LiveQueryAction] {
                notifications.map(\.action)
            }
        }

        let collector = NotificationCollector()

        // Start listening
        let listenTask = Task {
            for await notification in stream {
                await collector.append(notification)
                if notification.action == .close {
                    break
                }
                if await collector.count() >= 2 {
                    break
                }
            }
        }

        // Give the live query a moment to initialize
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Create a record
        struct User: Codable {
            let name: String
        }
        let _: User = try await db.create("users:live1", data: User(name: "Live User 1"))

        // Update the record
        let _: User = try await db.update("users:live1", data: User(name: "Live User Updated"))

        // Wait for notifications
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Kill the live query
        try await db.kill(queryId)

        await listenTask.value

        // Verify we received notifications
        let count = await collector.count()
        #expect(count >= 2)

        let actions = await collector.actions()
        #expect(actions.contains(.create) || actions.contains(.update))

        // Cleanup
        try await db.delete("users:live1")

        try await db.disconnect()
    }

    @Test("Query builder", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testQueryBuilder() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        struct User: Codable {
            let name: String
            let age: Int
        }

        // Create test data
        let users = [
            User(name: "Alice", age: 25),
            User(name: "Bob", age: 35),
            User(name: "Charlie", age: 20)
        ]

        for (index, user) in users.enumerated() {
            let _: User = try await db.create("users:user\(index)", data: user)
        }

        // Use query builder
        let results: [User] = try await db
            .query()
            .select("name", "age")
            .from("users")
            .where(field: "age", op: .greaterThanOrEqual, value: .int(25))
            .orderBy("age")
            .fetch()

        #expect(results.count >= 2)

        // Cleanup
        try await db.delete("users")

        try await db.disconnect()
    }

    @Test("Relationships", .enabled(if: ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1"))
    func testRelationships() async throws {
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        struct Person: Codable {
            let name: String
        }

        struct Post: Codable {
            let title: String
        }

        struct Authored: Codable {
            let publishedAt: String
        }

        // Create entities
        let _: Person = try await db.create("persons:john", data: Person(name: "John"))
        let _: Post = try await db.create("posts:post1", data: Post(title: "My Post"))

        // Create relationship
        let from = RecordID(table: "persons", id: "john")
        let to = RecordID(table: "posts", id: "post1")

        let edge: Authored = try await db.relate(
            from: from,
            via: "authored",
            to: to,
            data: Authored(publishedAt: "2024-01-01")
        )

        #expect(edge.publishedAt == "2024-01-01")

        // Cleanup
        try await db.delete("persons")
        try await db.delete("posts")
        _ = try await db.query("DELETE authored")

        try await db.disconnect()
    }
}
