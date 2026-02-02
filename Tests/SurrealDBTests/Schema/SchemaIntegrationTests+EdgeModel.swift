import Foundation
@testable import SurrealDB
import Testing

/// Integration tests for edge model schema.
extension SchemaIntegrationTests {
    // MARK: - Edge Model Tests

    @Test("Generate schema for edge model")
    func testEdgeModelSchemaGeneration() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // First create the user table
        try await db.defineTable(
            tableName: "testuser",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "email", type: "string", optional: false)
            ],
            mode: .schemafull,
            execute: true
        )

        // Generate edge schema without executing
        let statements = try await db.defineEdge(
            for: TestFollows.self,
            mode: .schemafull,
            execute: false
        )

        #expect(!statements.isEmpty)

        // Verify edge definition is present
        let hasEdgeDef = statements.contains { $0.contains("TYPE RELATION") }
        #expect(hasEdgeDef)

        // Verify IN/OUT constraints
        let hasInConstraint = statements.contains { $0.contains("IN testuser") }
        let hasOutConstraint = statements.contains { $0.contains("OUT testuser") }
        #expect(hasInConstraint)
        #expect(hasOutConstraint)

        // Clean up
        try await cleanup(db, tables: ["testuser", "testfollows"])
    }

    @Test("Execute edge schema creation")
    func testExecuteEdgeSchemaCreation() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create user table first
        try await db.defineTable(
            tableName: "testuser",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "email", type: "string", optional: false)
            ],
            mode: .schemafull,
            execute: true
        )

        // Create edge table
        let statements = try await db.defineEdge(
            edgeName: "follows",
            from: "testuser",
            to: "testuser",
            fields: [
                SchemaGenerator.FieldDefinition(name: "since", type: "datetime", optional: false)
            ],
            mode: .schemafull,
            execute: true
        )

        #expect(!statements.isEmpty)

        // Verify the edge table was created
        let info = try await db.describeTable("follows")
        #expect(info != .null)

        // Create test users
        struct SimpleUser: Codable {
            let name: String
            let email: String
        }

        let _: SimpleUser = try await db.create(
            "testuser:alice",
            data: SimpleUser(name: "Alice", email: "alice@example.com")
        )
        let _: SimpleUser = try await db.create(
            "testuser:bob",
            data: SimpleUser(name: "Bob", email: "bob@example.com")
        )

        // Create a relationship
        struct Follow: Codable {
            let since: String
        }

        let fromId = try RecordID(table: "testuser", id: "alice")
        let toId = try RecordID(table: "testuser", id: "bob")

        let follow: Follow = try await db.relate(
            from: fromId,
            via: "follows",
            to: toId,
            data: Follow(since: "2024-01-01T00:00:00Z")
        )

        #expect(follow.since == "2024-01-01T00:00:00Z")

        // Clean up
        try await cleanup(db, tables: ["testuser", "follows"])
    }
}
