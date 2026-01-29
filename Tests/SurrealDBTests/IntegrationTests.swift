import XCTest
@testable import SurrealDB

/// Integration tests that require a running SurrealDB instance.
///
/// To run these tests:
/// 1. Start SurrealDB: `surreal start --user root --pass root memory`
/// 2. Run tests: `SURREALDB_TEST=1 swift test`
final class IntegrationTests: XCTestCase {
    var db: SurrealDB!

    override func setUp() async throws {
        // Skip unless integration tests are enabled
        guard ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1" else {
            throw XCTSkip("Integration tests require SURREALDB_TEST=1 and running SurrealDB")
        }

        db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")
    }

    override func tearDown() async throws {
        if db != nil {
            try await db.disconnect()
        }
    }

    func testConnection() async throws {
        let connected = await db.isConnected
        XCTAssertTrue(connected)
    }

    func testPing() async throws {
        try await db.ping()
    }

    func testVersion() async throws {
        let version = try await db.version()
        XCTAssertFalse(version.isEmpty)
        print("SurrealDB version:", version)
    }

    func testCRUDOperations() async throws {
        struct User: Codable {
            let name: String
            let email: String
            let age: Int
        }

        // Create
        let newUser = User(name: "John Doe", email: "john@example.com", age: 30)
        let created: User = try await db.create("users:john", data: newUser)

        XCTAssertEqual(created.name, "John Doe")
        XCTAssertEqual(created.email, "john@example.com")
        XCTAssertEqual(created.age, 30)

        // Read
        let selected: [User] = try await db.select("users:john")
        XCTAssertEqual(selected.first?.name, "John Doe")

        // Update
        let updated: User = try await db.merge("users:john", data: ["age": 31])
        XCTAssertEqual(updated.age, 31)

        // Delete
        try await db.delete("users:john")

        // Verify deletion
        let deleted: [User] = try await db.select("users:john")
        XCTAssertTrue(deleted.isEmpty, "Record should be deleted")
    }

    func testQuery() async throws {
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

        XCTAssertGreaterThan(results.count, 0)

        // Cleanup
        try await db.delete("users")
    }

    func testLiveQueries() async throws {
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
        XCTAssertGreaterThanOrEqual(count, 2)

        let actions = await collector.actions()
        XCTAssertTrue(actions.contains(.create) || actions.contains(.update))

        // Cleanup
        try await db.delete("users:live1")
    }

    func testQueryBuilder() async throws {
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

        XCTAssertGreaterThanOrEqual(results.count, 2)

        // Cleanup
        try await db.delete("users")
    }

    func testRelationships() async throws {
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

        XCTAssertEqual(edge.publishedAt, "2024-01-01")

        // Cleanup
        try await db.delete("persons")
        try await db.delete("posts")
        _ = try await db.query("DELETE authored")
    }
}
