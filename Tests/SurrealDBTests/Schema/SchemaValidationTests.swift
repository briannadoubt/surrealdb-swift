import Foundation
@testable import SurrealDB
import Testing

/// Tests for schema validation and reserved keyword handling.
@Suite("Schema Validation")
struct SchemaValidationTests {
    // MARK: - Validation Tests

    @Test("Validate valid table names")
    func validateValidTableNames() throws {
        try SurrealValidator.validateTableName("users")
        try SurrealValidator.validateTableName("user_profiles")
        try SurrealValidator.validateTableName("_private")
        try SurrealValidator.validateTableName("table123")
    }

    @Test("Validate invalid table names")
    func validateInvalidTableNames() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("123invalid")
        }
    }

    @Test("Validate valid field names")
    func validateValidFieldNames() throws {
        try SurrealValidator.validateFieldName("email")
        try SurrealValidator.validateFieldName("user_email")
        try SurrealValidator.validateFieldName("address.city")
        try SurrealValidator.validateFieldName("nested.property.name")
    }

    @Test("Validate invalid field names")
    func validateInvalidFieldNames() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("123invalid")
        }
    }

    // MARK: - Reserved Keyword Tests

    @Test("Reject reserved keyword as table name")
    func rejectReservedKeywordAsTableName() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("select")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("from")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("table")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("index")
        }
    }

    @Test("Reject reserved keyword as field name")
    func rejectReservedKeywordAsFieldName() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("where")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("update")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("if")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("return")
        }
    }

    @Test("Reject reserved keyword case-insensitive")
    func rejectReservedKeywordCaseInsensitive() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("SELECT")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("Select")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("WHERE")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("Where")
        }
    }

    @Test("Accept backtick-quoted reserved keywords")
    func acceptBacktickQuotedReservedKeywords() throws {
        // Backtick-quoted identifiers should bypass reserved keyword check
        try SurrealValidator.validateTableName("`select`")
        try SurrealValidator.validateTableName("`from`")
        try SurrealValidator.validateFieldName("`where`")
        try SurrealValidator.validateFieldName("`update`")
    }

    @Test("Reject data type keywords as identifiers")
    func rejectDataTypeKeywords() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("string")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("int")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("bool")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("datetime")
        }
    }

    @Test("Reject literal keywords as identifiers")
    func rejectLiteralKeywords() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("true")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateTableName("false")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("null")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("none")
        }
    }

    @Test("Reject reserved keywords in nested field names")
    func rejectReservedKeywordsInNestedFields() {
        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("user.select")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("where.field")
        }

        #expect(throws: SurrealError.self) {
            try SurrealValidator.validateFieldName("valid.from.nested")
        }
    }

    @Test("Validate table builder with reserved keyword")
    func validateTableBuilderWithReservedKeyword() {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "select"
        )

        #expect(throws: SurrealError.self) {
            try builder.toSurrealQL()
        }
    }

    @Test("Validate field builder with reserved keyword")
    func validateFieldBuilderWithReservedKeyword() {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "where",
            tableName: "users"
        )
        .type(.string)

        #expect(throws: SurrealError.self) {
            try builder.toSurrealQL()
        }
    }

    @Test("Validate index builder with reserved keyword")
    func validateIndexBuilderWithReservedKeyword() {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "index",
            tableName: "users"
        )
        .fields("email")

        #expect(throws: SurrealError.self) {
            try builder.toSurrealQL()
        }
    }

    // MARK: - Helper Methods

    /// Creates a mock SurrealDB client for testing.
    private func createMockClient() -> SurrealDB {
        // Create a mock transport for testing
        let mockTransport = MockTransport()
        return SurrealDB(transport: mockTransport)
    }
}
