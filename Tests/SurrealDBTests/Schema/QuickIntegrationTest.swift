import Foundation
@testable import SurrealDB
import Testing

/// Quick diagnostic test to check SurrealDB connection
@Suite("Quick Integration Test")
struct QuickIntegrationTest {
    @Test("Test basic connection")
    func testBasicConnection() async throws {
        guard ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1" else {
            return // Skip test when environment variable not set
        }

        print("🔵 Starting connection test...")

        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        print("✅ Client created")

        print("🔵 Connecting...")
        try await db.connect()
        print("✅ Connected!")

        print("🔵 Signing in...")
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        print("✅ Signed in!")

        print("🔵 Using namespace/database...")
        try await db.use(namespace: "test", database: "test")
        print("✅ Using test database!")

        print("🔵 Running simple query...")
        let result: [SurrealValue] = try await db.query("SELECT * FROM test")
        print("✅ Query result: \(result)")

        print("🔵 Disconnecting...")
        try await db.disconnect()
        print("✅ All tests passed!")
    }
}
