@testable import SurrealDB
import Testing

@Suite("Schema Generator Tests")
struct SchemaGeneratorTests {
    // swiftlint:disable identifier_name
    // MARK: - Test Models

    struct TestUser: SurrealModel, HasSchemaDescriptor {
        var id: RecordID?
        var name: String
        var email: String
        var age: Int

        static let _schemaDescriptor = SchemaDescriptor(
            tableName: "testuser",
            fields: [
                FieldDescriptor(name: "id", type: .record(table: "testuser"), isOptional: true),
                FieldDescriptor(name: "name", type: .string),
                FieldDescriptor(name: "email", type: .string),
                FieldDescriptor(name: "age", type: .int),
                FieldDescriptor(name: "nickname", type: .string, isOptional: true)
            ]
        )
    }

    struct TestEdge: EdgeModel, HasSchemaDescriptor {
        typealias From = TestUser
        typealias To = TestUser
        var since: String

        static let _schemaDescriptor = SchemaDescriptor(
            tableName: "testedge",
            fields: [
                FieldDescriptor(name: "since", type: .string)
            ],
            isEdge: true,
            edgeFrom: TestUser.tableName,
            edgeTo: TestUser.tableName
        )
    }

    struct MissingDescriptorModel: SurrealModel {
        var id: RecordID?
        var title: String
    }

    // MARK: - Table Schema Generation Tests

    @Test("Generate table schema in schemafull mode")
    func testGenerateTableSchemaSchemafull() throws {
        let statements = try SchemaGenerator.generateTableSchema(
            for: TestUser.self,
            mode: .schemafull
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains(where: { $0.contains("DEFINE TABLE") }))
        #expect(statements.contains(where: { $0.contains("SCHEMAFULL") }))
        #expect(statements.contains(where: { $0.contains("DEFINE FIELD name ON TABLE testuser TYPE string;") }))
        #expect(statements.contains(where: { $0.contains("DEFINE FIELD age ON TABLE testuser TYPE int;") }))
        #expect(statements.contains(where: { $0.contains("DEFINE FIELD nickname ON TABLE testuser TYPE string FLEXIBLE;") }))
        #expect(!statements.contains(where: { $0.contains("DEFINE FIELD id ") }))
    }

    @Test("Generate table schema in schemaless mode")
    func testGenerateTableSchemaSchemaless() throws {
        let statements = try SchemaGenerator.generateTableSchema(
            for: TestUser.self,
            mode: .schemaless
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains(where: { $0.contains("DEFINE TABLE") }))
        #expect(statements.contains(where: { $0.contains("SCHEMALESS") }))
        // Schemaless mode should not include field definitions
        #expect(!statements.contains(where: { $0.contains("DEFINE FIELD") }))
    }

    @Test("Generate table schema with drop")
    func testGenerateTableSchemaWithDrop() throws {
        let statements = try SchemaGenerator.generateTableSchema(
            for: TestUser.self,
            mode: .schemafull,
            drop: true
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains(where: { $0.contains("REMOVE TABLE") }))
    }

    // MARK: - Edge Schema Generation Tests

    @Test("Generate edge schema in schemafull mode")
    func testGenerateEdgeSchemaSchemafull() throws {
        let statements = try SchemaGenerator.generateEdgeSchema(
            for: TestEdge.self,
            mode: .schemafull
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains(where: { $0.contains("DEFINE TABLE") }))
        #expect(statements.contains(where: { $0.contains("TYPE RELATION") }))
        #expect(statements.contains(where: { $0.contains("IN testuser") }))
        #expect(statements.contains(where: { $0.contains("OUT testuser") }))
        #expect(statements.contains(where: { $0.contains("DEFINE FIELD since ON TABLE testedge TYPE string;") }))
    }

    @Test("Generate edge schema with drop")
    func testGenerateEdgeSchemaWithDrop() throws {
        let statements = try SchemaGenerator.generateEdgeSchema(
            for: TestEdge.self,
            mode: .schemafull,
            drop: true
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains(where: { $0.contains("REMOVE TABLE") }))
    }

    // MARK: - Convenience Method Tests

    @Test("Generate schema with explicit fields")
    func testGenerateSchemaWithFields() {
        let statements = SchemaGenerator.generateSchema(
            tableName: "test_table",
            fields: [
                SchemaGenerator.FieldDefinition(name: "name", type: "string", optional: false),
                SchemaGenerator.FieldDefinition(name: "age", type: "int", optional: true),
                SchemaGenerator.FieldDefinition(name: "email", type: "string", optional: false)
            ],
            mode: .schemafull
        )

        #expect(!statements.isEmpty)
        #expect(statements.contains(where: { $0.contains("DEFINE TABLE test_table") }))
        #expect(statements.contains(where: { $0.contains("DEFINE FIELD name") }))
        #expect(statements.contains(where: { $0.contains("DEFINE FIELD age") }))
        #expect(statements.contains(where: { $0.contains("FLEXIBLE") })) // Optional field
    }

    // MARK: - Type Mapping Tests

    @Test("Generate table schema fails without schema descriptor")
    func testGenerateTableSchemaWithoutDescriptorFails() {
        var thrownError: SurrealError?
        do {
            _ = try SchemaGenerator.generateTableSchema(for: MissingDescriptorModel.self, mode: .schemafull)
        } catch {
            thrownError = error
        }

        #expect(thrownError != nil)
        if case .encodingError(let message) = thrownError {
            #expect(message.contains("HasSchemaDescriptor"))
        } else {
            Issue.record("Expected encodingError for missing schema descriptor")
        }
    }

    @Test("Map Swift types to SurrealDB types")
    func testMapSwiftType() {
        #expect(SchemaGenerator.mapSwiftType("String") == "string")
        #expect(SchemaGenerator.mapSwiftType("Int") == "int")
        #expect(SchemaGenerator.mapSwiftType("Double") == "float")
        #expect(SchemaGenerator.mapSwiftType("Bool") == "bool")
        #expect(SchemaGenerator.mapSwiftType("Date") == "datetime")
        #expect(SchemaGenerator.mapSwiftType("UUID") == "string")
        #expect(SchemaGenerator.mapSwiftType("Data") == "bytes")
        #expect(SchemaGenerator.mapSwiftType("Array<String>") == "array")
        #expect(SchemaGenerator.mapSwiftType("Dictionary<String, Any>") == "object")
    }
    // swiftlint:enable identifier_name
}
