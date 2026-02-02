import Foundation
@testable import SurrealDB
import Testing

/// Integration tests for schema modes and table operations.
extension SchemaIntegrationTests {
    // MARK: - Drop and Recreate Tests

    @Test("Drop and recreate table")
    func testDropAndRecreateTable() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create initial table
        try await db.defineTable(
            tableName: "drop_test",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false)
            ],
            mode: .schemafull,
            execute: true
        )

        // Verify it exists
        var tables = try await db.listTables()
        #expect(tables.contains("drop_test"))

        // Drop and recreate
        let statements = try await db.defineTable(
            tableName: "drop_test",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "email", type: "string", optional: false)
            ],
            mode: .schemafull,
            drop: true,
            execute: true
        )

        #expect(statements.contains { $0.contains("REMOVE TABLE") })

        // Verify it still exists (recreated)
        tables = try await db.listTables()
        #expect(tables.contains("drop_test"))

        // Clean up
        try await cleanup(db, tables: ["drop_test"])
    }

    @Test("Remove table using schema builder")
    func testRemoveTable() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create a table
        try await db.schema
            .defineTable("remove_test")
            .schemafull()
            .execute()

        // Verify it exists
        var tables = try await db.listTables()
        #expect(tables.contains("remove_test"))

        // Remove the table
        try await db.schema.removeTable("remove_test")

        // Verify it's gone
        tables = try await db.listTables()
        #expect(!tables.contains("remove_test"))
    }

    // MARK: - Schema Mode Tests

    @Test("Schemaless table accepts any fields")
    func testSchemalessTable() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create schemaless table
        try await db.schema
            .defineTable("schemaless_test")
            .schemaless()
            .execute()

        // Insert record with arbitrary fields
        struct AnyRecord: Codable {
            let name: String
            let randomField: String
            let anotherField: Int
        }

        let record = AnyRecord(
            name: "Test",
            randomField: "value",
            anotherField: 42
        )

        let created: AnyRecord = try await db.create("schemaless_test:test1", data: record)

        #expect(created.name == "Test")
        #expect(created.randomField == "value")
        #expect(created.anotherField == 42)

        // Clean up
        try await cleanup(db, tables: ["schemaless_test"])
    }

    @Test("Schemafull table rejects undefined fields")
    func testSchemafullTableRejectsUndefinedFields() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Create schemafull table with specific fields
        try await db.schema
            .defineTable("schemafull_test")
            .schemafull()
            .execute()

        try await db.schema
            .defineField("name", on: "schemafull_test")
            .type(.string)
            .execute()

        try await db.schema
            .defineField("email", on: "schemafull_test")
            .type(.string)
            .execute()

        // Insert record with only defined fields should work
        struct ValidRecord: Codable {
            let name: String
            let email: String
        }

        let validRecord = ValidRecord(name: "Test", email: "test@example.com")
        let created: ValidRecord = try await db.create("schemafull_test:valid", data: validRecord)

        #expect(created.name == "Test")
        #expect(created.email == "test@example.com")

        // Clean up
        try await cleanup(db, tables: ["schemafull_test"])
    }
}
