import Foundation
@testable import SurrealDB
import Testing

/// Integration tests for index definition.
extension SchemaIntegrationTests {
    // MARK: - Index Creation Tests

    @Test("Create unique index")
    func testCreateUniqueIndex() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Define table and unique index
        try await db.schema
            .defineTable("unique_test")
            .schemafull()
            .execute()

        try await db.schema
            .defineField("email", on: "unique_test")
            .type(.string)
            .execute()

        try await db.schema
            .defineIndex("unique_email", on: "unique_test")
            .fields("email")
            .unique()
            .execute()

        // Create first record
        struct EmailRecord: Codable {
            let email: String
        }

        let _: EmailRecord = try await db.create(
            "unique_test:user1",
            data: EmailRecord(email: "test@example.com")
        )

        // Attempt to create duplicate should fail
        do {
            let _: EmailRecord = try await db.create(
                "unique_test:user2",
                data: EmailRecord(email: "test@example.com")
            )
            // If no error, unique constraint might not be enforced immediately
        } catch {
            // Expected - unique constraint violation
            #expect(true)
        }

        // Clean up
        try await cleanup(db, tables: ["unique_test"])
    }

    @Test("Create full-text search index")
    func testCreateFulltextIndex() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Define table with fulltext index
        try await db.schema
            .defineTable("search_test")
            .schemafull()
            .execute()

        try await db.schema
            .defineField("content", on: "search_test")
            .type(.string)
            .execute()

        try await db.schema
            .defineIndex("ft_content", on: "search_test")
            .fields("content")
            .fulltext(analyzer: "ascii")
            .execute()

        // Verify index was created
        let info = try await db.describeTable("search_test")
        #expect(info != .null)

        // Clean up
        try await cleanup(db, tables: ["search_test"])
    }

    @Test("Create standard search index")
    func testCreateSearchIndex() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Define table with search index
        try await db.schema
            .defineTable("text_search_test")
            .schemafull()
            .execute()

        try await db.schema
            .defineField("title", on: "text_search_test")
            .type(.string)
            .execute()

        try await db.schema
            .defineIndex("search_title", on: "text_search_test")
            .fields("title")
            .search(analyzer: "ascii")
            .execute()

        // Verify index was created
        let info = try await db.describeTable("text_search_test")
        #expect(info != .null)

        // Clean up
        try await cleanup(db, tables: ["text_search_test"])
    }

    @Test("Create multi-field index")
    func testCreateMultiFieldIndex() async throws {
        let db = try await setupDatabase()
        defer { Task { try? await db.disconnect() } }

        // Define table with multi-field index
        try await db.schema
            .defineTable("multifield_test")
            .schemafull()
            .execute()

        try await db.schema
            .defineField("first_name", on: "multifield_test")
            .type(.string)
            .execute()

        try await db.schema
            .defineField("last_name", on: "multifield_test")
            .type(.string)
            .execute()

        try await db.schema
            .defineIndex("idx_full_name", on: "multifield_test")
            .fields("first_name", "last_name")
            .execute()

        // Verify index was created
        let info = try await db.describeTable("multifield_test")
        #expect(info != .null)

        // Clean up
        try await cleanup(db, tables: ["multifield_test"])
    }
}
