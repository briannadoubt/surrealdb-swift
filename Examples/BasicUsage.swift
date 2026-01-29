import Foundation
import SurrealDB

// This example demonstrates basic usage of the SurrealDB Swift client.
// To run this example:
// 1. Start SurrealDB: surreal start --user root --pass root memory
// 2. Run: swift run

@main
struct BasicUsage {
    static func main() async throws {
        // Create and connect to SurrealDB
        let db = try SurrealDB(url: "ws://localhost:8000/rpc", transportType: .websocket)
        try await db.connect()

        // Authenticate
        try await db.signin(.root(RootAuth(username: "root", password: "root")))

        // Select namespace and database
        try await db.use(namespace: "test", database: "test")

        // Define a model
        struct User: Codable {
            let id: String?
            let name: String
            let email: String
            let age: Int
        }

        print("Creating users...")

        // Create records
        let user1: User = try await db.create("users:alice", data: User(
            id: nil,
            name: "Alice",
            email: "alice@example.com",
            age: 28
        ))
        print("Created:", user1.name)

        let user2: User = try await db.create("users:bob", data: User(
            id: nil,
            name: "Bob",
            email: "bob@example.com",
            age: 32
        ))
        print("Created:", user2.name)

        // Query all users
        print("\nQuerying all users...")
        let allUsers: [User] = try await db.select("users")
        print("Found \(allUsers.count) users:")
        for user in allUsers {
            print("  - \(user.name), age \(user.age)")
        }

        // Use the query builder
        print("\nUsing query builder...")
        let adults: [User] = try await db
            .query()
            .select("name", "email", "age")
            .from("users")
            .where("age >= 30")
            .orderBy("name")
            .fetch()

        print("Adults (age >= 30):")
        for user in adults {
            print("  - \(user.name), age \(user.age)")
        }

        // Update a record
        print("\nUpdating Bob's age...")
        let updated: User = try await db.merge("users:bob", data: ["age": 33])
        print("Updated:", updated.name, "age:", updated.age)

        // Custom query
        print("\nCustom query with variables...")
        let results = try await db.query(
            "SELECT name, email FROM users WHERE age > $minAge",
            variables: ["minAge": .int(25)]
        )
        print("Query results:", results)

        // Delete a record
        print("\nDeleting Alice...")
        try await db.delete("users:alice")

        let remaining: [User] = try await db.select("users")
        print("Remaining users:", remaining.count)

        // Cleanup
        print("\nCleaning up...")
        try await db.delete("users")

        // Disconnect
        try await db.disconnect()
        print("\nDisconnected.")
    }
}
