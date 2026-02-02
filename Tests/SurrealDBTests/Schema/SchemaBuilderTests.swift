import Foundation
@testable import SurrealDB
import Testing

/// Tests for the schema builder fluent API.
@Suite("Schema Builders")
struct SchemaBuilderTests {
    // MARK: - Table Definition Tests

    @Test("Define basic table")
    func defineBasicTable() throws {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "users"
        )

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE TABLE users")
    }

    @Test("Define schemafull table")
    func defineSchemafullTable() throws {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "users"
        )
        .schemafull()

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE TABLE users SCHEMAFULL")
    }

    @Test("Define schemaless table")
    func defineSchemalessTable() throws {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "events"
        )
        .schemaless()

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE TABLE events SCHEMALESS")
    }

    @Test("Define relation table")
    func defineRelationTable() throws {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "follows"
        )
        .relation(from: "users", to: "users")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE TABLE follows TYPE RELATION IN users OUT users")
    }

    @Test("Define table with IF NOT EXISTS")
    func defineTableIfNotExists() throws {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "users"
        )
        .schemafull()
        .ifNotExists()

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE TABLE IF NOT EXISTS users SCHEMAFULL")
    }

    @Test("Drop table")
    func dropTable() throws {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "old_users"
        )
        .drop()

        let sql = try builder.toSurrealQL()
        #expect(sql == "REMOVE TABLE old_users")
    }

    @Test("Validate table name")
    func validateTableName() throws {
        let builder = TableDefinitionBuilder(
            client: createMockClient(),
            tableName: "123invalid"
        )

        #expect(throws: SurrealError.self) {
            try builder.toSurrealQL()
        }
    }

    // MARK: - Field Definition Tests

    @Test("Define basic field")
    func defineBasicField() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "email",
            tableName: "users"
        )
        .type(.string)

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD email ON TABLE users TYPE string")
    }

    @Test("Define field with default value")
    func defineFieldWithDefault() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "created_at",
            tableName: "users"
        )
        .type(.datetime)
        .default("time::now()")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD created_at ON TABLE users TYPE datetime DEFAULT time::now()")
    }

    @Test("Define field with value expression")
    func defineFieldWithValue() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "full_name",
            tableName: "users"
        )
        .type(.string)
        .value("string::concat($this.first_name, ' ', $this.last_name)")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD full_name ON TABLE users TYPE string VALUE string::concat($this.first_name, ' ', $this.last_name)")
    }

    @Test("Define field with assertion")
    func defineFieldWithAssertion() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "age",
            tableName: "users"
        )
        .type(.int)
        .assert("$value >= 0 AND $value <= 150")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD age ON TABLE users TYPE int ASSERT $value >= 0 AND $value <= 150")
    }

    @Test("Define flexible field")
    func defineFlexibleField() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "metadata",
            tableName: "users"
        )
        .type(.object)
        .flexible()

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD metadata ON TABLE users TYPE object FLEXIBLE")
    }

    @Test("Define field with IF NOT EXISTS")
    func defineFieldIfNotExists() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "email",
            tableName: "users"
        )
        .type(.string)
        .ifNotExists()

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD IF NOT EXISTS email ON TABLE users TYPE string")
    }

    @Test("Define optional field")
    func defineOptionalField() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "bio",
            tableName: "users"
        )
        .type(.option(of: .string))

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD bio ON TABLE users TYPE option<string>")
    }

    @Test("Define array field")
    func defineArrayField() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "tags",
            tableName: "posts"
        )
        .type(.array(of: .string))

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD tags ON TABLE posts TYPE array<string>")
    }

    @Test("Define record field")
    func defineRecordField() throws {
        let builder = FieldDefinitionBuilder(
            client: createMockClient(),
            fieldName: "author",
            tableName: "posts"
        )
        .type(.record(table: "users"))

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE FIELD author ON TABLE posts TYPE record<users>")
    }

    // MARK: - Index Definition Tests

    @Test("Define basic index")
    func defineBasicIndex() throws {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "idx_email",
            tableName: "users"
        )
        .fields("email")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE INDEX idx_email ON TABLE users FIELDS email")
    }

    @Test("Define unique index")
    func defineUniqueIndex() throws {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "unique_email",
            tableName: "users"
        )
        .fields("email")
        .unique()

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE INDEX unique_email ON TABLE users FIELDS email UNIQUE")
    }

    @Test("Define index with multiple fields")
    func defineMultiFieldIndex() throws {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "idx_name",
            tableName: "users"
        )
        .fields("first_name", "last_name")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE INDEX idx_name ON TABLE users FIELDS first_name, last_name")
    }

    @Test("Define full-text search index")
    func defineFulltextIndex() throws {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "ft_content",
            tableName: "posts"
        )
        .fields("content")
        .fulltext(analyzer: "ascii")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE INDEX ft_content ON TABLE posts FIELDS content SEARCH ANALYZER ascii BM25")
    }

    @Test("Define search index")
    func defineSearchIndex() throws {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "search_title",
            tableName: "posts"
        )
        .fields("title")
        .search(analyzer: "ascii")

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE INDEX search_title ON TABLE posts FIELDS title SEARCH ANALYZER ascii")
    }

    @Test("Define index with IF NOT EXISTS")
    func defineIndexIfNotExists() throws {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "idx_email",
            tableName: "users"
        )
        .fields("email")
        .ifNotExists()

        let sql = try builder.toSurrealQL()
        #expect(sql == "DEFINE INDEX IF NOT EXISTS idx_email ON TABLE users FIELDS email")
    }

    @Test("Validate index with no fields")
    func validateIndexWithNoFields() throws {
        let builder = IndexDefinitionBuilder(
            client: createMockClient(),
            indexName: "idx_test",
            tableName: "users"
        )
        // No fields specified

        #expect(throws: SurrealError.self) {
            try builder.toSurrealQL()
        }
    }

    // MARK: - Type System Tests

    @Test("Field type SurrealQL generation")
    func fieldTypeSurrealQL() {
        #expect(FieldType.string.toSurrealQL() == "string")
        #expect(FieldType.int.toSurrealQL() == "int")
        #expect(FieldType.bool.toSurrealQL() == "bool")
        #expect(FieldType.datetime.toSurrealQL() == "datetime")
        #expect(FieldType.uuid.toSurrealQL() == "uuid")
        #expect(FieldType.array(of: .string).toSurrealQL() == "array<string>")
        #expect(FieldType.option(of: .int).toSurrealQL() == "option<int>")
        #expect(FieldType.record(table: "users").toSurrealQL() == "record<users>")
        #expect(FieldType.record(table: nil).toSurrealQL() == "record")
    }

    @Test("Nested field types")
    func nestedFieldTypes() {
        let arrayOfOptionalStrings = FieldType.array(of: .option(of: .string))
        #expect(arrayOfOptionalStrings.toSurrealQL() == "array<option<string>>")

        let optionalArrayOfInts = FieldType.option(of: .array(of: .int))
        #expect(optionalArrayOfInts.toSurrealQL() == "option<array<int>>")
    }

    @Test("Schema mode SurrealQL generation")
    func schemaModeSurrealQL() {
        #expect(SchemaMode.schemafull.toSurrealQL() == "SCHEMAFULL")
        #expect(SchemaMode.schemaless.toSurrealQL() == "SCHEMALESS")
    }

    @Test("Table type SurrealQL generation")
    func tableTypeSurrealQL() {
        #expect(TableType.normal.toSurrealQL().isEmpty)
        #expect(TableType.relation(from: "users", to: "posts").toSurrealQL() == "TYPE RELATION IN users OUT posts")
    }

    @Test("Index type SurrealQL generation")
    func indexTypeSurrealQL() {
        #expect(IndexType.standard.toSurrealQL().isEmpty)
        #expect(IndexType.unique.toSurrealQL() == "UNIQUE")
        #expect(IndexType.fulltext(analyzer: "ascii").toSurrealQL() == "SEARCH ANALYZER ascii BM25")
        #expect(IndexType.search(analyzer: nil).toSurrealQL() == "SEARCH ANALYZER LIKE")
    }

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
        try SurrealValidator.validateFieldName("nested.field.name")
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

    // MARK: - Helper Methods

    /// Creates a mock SurrealDB client for testing.
    private func createMockClient() -> SurrealDB {
        // Create a mock transport for testing
        let mockTransport = MockTransport()
        return SurrealDB(transport: mockTransport)
    }
}
