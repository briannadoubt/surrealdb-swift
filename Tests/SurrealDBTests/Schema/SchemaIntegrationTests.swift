import Foundation
@testable import SurrealDB
import Testing

/// Integration tests for schema management that require a running SurrealDB instance.
///
/// To run these tests:
/// 1. Start SurrealDB: `surreal start --user root --pass root memory`
/// 2. Run tests: `SURREALDB_TEST=1 swift test`
@Suite("Schema Integration Tests")
struct SchemaIntegrationTests {
    // MARK: - Test Models

    struct TestUser: SurrealModel, Codable {
        var id: RecordID?
        var name: String
        var email: String
        var age: Int?
        var createdAt: Date
    }

    struct TestFollows: EdgeModel, Codable {
        typealias From = TestUser
        typealias To = TestUser
        var since: Date
    }

    struct TestPost: SurrealModel, Codable {
        var id: RecordID?
        var title: String
        var content: String
        var authorId: RecordID
        var tags: [String]
        var published: Bool
    }

    // MARK: - Helper Methods

    func setupDatabase() async throws -> SurrealDB? {
        guard ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1" else {
            return nil // Skip test when environment variable not set
        }

        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")
        return db
    }

    func cleanup(_ db: SurrealDB, tables: [String]) async throws {
        for table in tables {
            _ = try? await db.query("REMOVE TABLE \(table)")
        }
    }
}
