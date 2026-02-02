import Foundation
@testable import SurrealDB
import Testing

/// Integration tests for schema introspection.
extension SchemaIntegrationTests {
    // MARK: - Schema Introspection Tests

    @Test("Describe table schema")
    func testDescribeTable() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create a table
        try await db.defineTable(
            tableName: "describe_test",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "age", type: "int", optional: true)
            ],
            mode: .schemafull,
            execute: true
        )

        // Describe the table
        let info = try await db.describeTable("describe_test")

        // Verify we got information back
        #expect(info != .null)

        // The info should be an object containing table metadata
        if case .object(let infoObj) = info {
            #expect(!infoObj.isEmpty)
        } else {
            Issue.record("Expected object result from describeTable")
        }

        // Clean up
        try await cleanup(db, tables: ["describe_test"])
    }

    @Test("List all tables")
    func testListTables() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create several tables
        try await db.schema
            .defineTable("list_test_1")
            .schemafull()
            .execute()

        try await db.schema
            .defineTable("list_test_2")
            .schemafull()
            .execute()

        try await db.schema
            .defineTable("list_test_3")
            .schemafull()
            .execute()

        // List all tables
        let tables = try await db.listTables()

        // Verify our tables are present
        #expect(tables.contains("list_test_1"))
        #expect(tables.contains("list_test_2"))
        #expect(tables.contains("list_test_3"))

        // Clean up
        try await cleanup(db, tables: ["list_test_1", "list_test_2", "list_test_3"])
    }

    @Test("Get database info")
    func testGetDatabaseInfo() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create a table
        try await db.schema
            .defineTable("info_test")
            .schemafull()
            .execute()

        // Get database info
        let info = try await db.schema.info()

        // Verify we got information back
        #expect(info != .null)

        // The info should contain table definitions
        if case .object(let infoObj) = info {
            #expect(!infoObj.isEmpty)
        } else {
            Issue.record("Expected object result from schema.info()")
        }

        // Clean up
        try await cleanup(db, tables: ["info_test"])
    }

    // MARK: - Dry Run Mode Tests

    @Test("Dry run table definition")
    func testDryRunTableDefinition() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Generate statements without execution
        let statements = try await db.defineTable(
            tableName: "dryrun_test",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "email", type: "string", optional: false)
            ],
            mode: .schemafull,
            execute: false
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains { $0.contains("DEFINE TABLE dryrun_test") })

        // Verify the table was NOT created
        let tables = try await db.listTables()
        #expect(!tables.contains("dryrun_test"))
    }

    @Test("Dry run edge definition")
    func testDryRunEdgeDefinition() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Generate edge statements without execution
        let statements = try await db.defineEdge(
            edgeName: "dryrun_edge",
            from: "users",
            to: "posts",
            fields: [
                SchemaGenerator.FieldDefinition(name: "created_at", type: "datetime", optional: false)
            ],
            mode: .schemafull,
            execute: false
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains { $0.contains("DEFINE TABLE dryrun_edge") })
        #expect(statements.contains { $0.contains("TYPE RELATION") })
        #expect(statements.contains { $0.contains("IN users") })
        #expect(statements.contains { $0.contains("OUT posts") })

        // Verify the table was NOT created
        let tables = try await db.listTables()
        #expect(!tables.contains("dryrun_edge"))
    }
}
