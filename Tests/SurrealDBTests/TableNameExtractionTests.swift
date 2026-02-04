import Foundation
@testable import SurrealDB
import Testing

// MARK: - Table Name Extraction Tests

@Suite("Table Name Extraction Tests")
struct TableNameExtractionTests {
    @Test("extractTableName from plain table name")
    func extractTableNamePlain() {
        let result = SurrealDB.extractTableName(from: "users")
        #expect(result == "users")
    }

    @Test("extractTableName from record ID")
    func extractTableNameFromRecordID() {
        let result = SurrealDB.extractTableName(from: "users:123")
        #expect(result == "users")
    }

    @Test("extractTableName from record ID with string ID")
    func extractTableNameFromStringRecordID() {
        let result = SurrealDB.extractTableName(from: "users:john_doe")
        #expect(result == "users")
    }

    @Test("extractTableName from record ID with complex ID")
    func extractTableNameFromComplexRecordID() {
        let result = SurrealDB.extractTableName(from: "events:2024:01:15")
        #expect(result == "events")
    }

    @Test("extractTableNames from simple SELECT")
    func extractTableNamesFromSimpleSelect() {
        let result = SurrealDB.extractTableNames(from: "SELECT * FROM users")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from SELECT with WHERE clause")
    func extractTableNamesFromSelectWithWhere() {
        let result = SurrealDB.extractTableNames(from: "SELECT * FROM users WHERE age > 18")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from subquery")
    func extractTableNamesFromSubquery() {
        let sql = "SELECT * FROM users WHERE id IN (SELECT id FROM orders)"
        let result = SurrealDB.extractTableNames(from: sql)
        #expect(result == Set(["users", "orders"]))
    }

    @Test("extractTableNames from CREATE statement")
    func extractTableNamesFromCreate() {
        let result = SurrealDB.extractTableNames(from: "CREATE users SET name = 'John'")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from UPDATE statement")
    func extractTableNamesFromUpdate() {
        let result = SurrealDB.extractTableNames(from: "UPDATE users SET active = true")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from DELETE statement")
    func extractTableNamesFromDelete() {
        let result = SurrealDB.extractTableNames(from: "DELETE users WHERE inactive = true")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from INSERT INTO statement")
    func extractTableNamesFromInsertInto() {
        let result = SurrealDB.extractTableNames(from: "INSERT INTO users (name) VALUES ('Alice')")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from UPSERT statement")
    func extractTableNamesFromUpsert() {
        let result = SurrealDB.extractTableNames(from: "UPSERT users SET name = 'John'")
        #expect(result == Set(["users"]))
    }

    @Test("extractTableNames from complex query with multiple tables")
    func extractTableNamesFromComplexQuery() {
        let sql = """
        SELECT * FROM users WHERE id IN (
            SELECT user_id FROM orders WHERE product_id IN (
                SELECT id FROM products
            )
        )
        """
        let result = SurrealDB.extractTableNames(from: sql)
        #expect(result.contains("users"))
        #expect(result.contains("orders"))
        #expect(result.contains("products"))
    }

    @Test("extractTableNames is case insensitive for keywords")
    func extractTableNamesCaseInsensitive() {
        let result1 = SurrealDB.extractTableNames(from: "select * from users")
        let result2 = SurrealDB.extractTableNames(from: "SELECT * FROM users")
        let result3 = SurrealDB.extractTableNames(from: "Select * From users")

        #expect(result1 == Set(["users"]))
        #expect(result2 == Set(["users"]))
        #expect(result3 == Set(["users"]))
    }

    @Test("extractTableNames from query with no recognizable tables")
    func extractTableNamesFromEmptyQuery() {
        let result = SurrealDB.extractTableNames(from: "RETURN 1 + 2")
        #expect(result.isEmpty)
    }

    @Test("extractTableNames with underscored table names")
    func extractTableNamesWithUnderscores() {
        let result = SurrealDB.extractTableNames(from: "SELECT * FROM user_profiles")
        #expect(result == Set(["user_profiles"]))
    }

    @Test("extractTableNames with multiple FROM clauses")
    func extractTableNamesMultipleFromClauses() {
        let sql = "SELECT * FROM users; SELECT * FROM posts"
        let result = SurrealDB.extractTableNames(from: sql)
        #expect(result.contains("users"))
        #expect(result.contains("posts"))
    }
}
