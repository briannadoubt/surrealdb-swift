import Foundation
@testable import SurrealDB
import Testing

/// Integration tests for table definition.
extension SchemaIntegrationTests {
    // MARK: - Automatic Schema Generation Tests

    @Test("Generate schema from SurrealModel")
    func testAutomaticSchemaGeneration() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Generate schema statements without executing
        let statements = try await db.defineTable(
            for: TestUser.self,
            mode: .schemafull,
            execute: false
        )

        #expect(!statements.isEmpty)

        // Verify table definition is present
        let tableDefExists = statements.contains { $0.contains("DEFINE TABLE") }
        #expect(tableDefExists)

        // Verify table name is correct (lowercased by default)
        let correctTableName = statements.contains { $0.contains("testuser") }
        #expect(correctTableName)

        // Verify schemafull mode
        let isSchemafull = statements.contains { $0.contains("SCHEMAFULL") }
        #expect(isSchemafull)

        // Clean up
        try await cleanup(db, tables: ["testuser"])
    }

    @Test("Execute schema generation for SurrealModel")
    func testExecuteSchemaGeneration() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Execute schema generation
        let statements = try await db.defineTable(
            for: TestPost.self,
            mode: .schemafull,
            execute: true
        )

        #expect(!statements.isEmpty)

        // Verify the table was created by querying info
        let info = try await db.describeTable("testpost")
        #expect(info != .null)

        // Clean up
        try await cleanup(db, tables: ["testpost"])
    }

    // MARK: - Manual Table Definition Tests

    @Test("Define table with manual field definitions")
    func testManualTableDefinition() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Define table with explicit fields
        let statements = try await db.defineTable(
            tableName: "manual_users",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "email", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "age", type: "int", optional: true),
                SchemaGenerator.FieldDefinition(name: "bio", type: "string", optional: true)
            ],
            mode: .schemafull,
            execute: true
        )

        #expect(!statements.isEmpty)

        // Verify the table was created
        let info = try await db.describeTable("manual_users")
        #expect(info != .null)

        // Test inserting data that conforms to schema
        struct ManualUser: Codable {
            let name: String
            let email: String
            let age: Int?
        }

        let user = ManualUser(name: "Alice", email: "alice@example.com", age: 30)
        let created: ManualUser = try await db.create("manual_users:alice", data: user)

        #expect(created.name == "Alice")
        #expect(created.email == "alice@example.com")

        // Clean up
        try await cleanup(db, tables: ["manual_users"])
    }

    @Test("Define table using schema builder")
    func testSchemaBuilderTableDefinition() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Define table using fluent API
        try await db.schema
            .defineTable("builder_users")
            .schemafull()
            .ifNotExists()
            .execute()

        // Verify the table was created
        let info = try await db.describeTable("builder_users")
        #expect(info != .null)

        // Clean up
        try await cleanup(db, tables: ["builder_users"])
    }
}
