import Testing
@testable import SurrealDB

@Suite("KeyPath Field Extraction")
struct KeyPathExtractionTests {

    // MARK: - Simple Field Extraction

    @Test("Extract simple string field")
    func extractSimpleStringField() {
        let fieldName = extractFieldName(from: \TestUser.name)
        #expect(fieldName == "name")
    }

    @Test("Extract simple int field")
    func extractSimpleIntField() {
        let fieldName = extractFieldName(from: \TestUser.age)
        #expect(fieldName == "age")
    }

    @Test("Extract simple optional field")
    func extractSimpleOptionalField() {
        let fieldName = extractFieldName(from: \TestUser.id)
        #expect(fieldName == "id")
    }

    // MARK: - Complex Type Extraction

    @Test("Extract nested struct field")
    func extractNestedStructField() {
        struct Outer: Codable, Sendable {
            struct Inner: Codable, Sendable {
                var value: String
            }
            var inner: Inner
        }

        let fieldName = extractFieldName(from: \Outer.inner)
        #expect(fieldName == "inner")
    }

    @Test("Extract array field")
    func extractArrayField() {
        struct Container: Codable, Sendable {
            var items: [String]
        }

        let fieldName = extractFieldName(from: \Container.items)
        #expect(fieldName == "items")
    }

    @Test("Extract dictionary field")
    func extractDictionaryField() {
        struct Container: Codable, Sendable {
            var metadata: [String: String]
        }

        let fieldName = extractFieldName(from: \Container.metadata)
        #expect(fieldName == "metadata")
    }

    // MARK: - Optional Field Extraction

    @Test("Extract optional RecordID field")
    func extractOptionalRecordID() {
        let fieldName = extractFieldName(from: \TestUser.id)
        #expect(fieldName == "id")
    }

    @Test("Extract email field")
    func extractEmailField() {
        let fieldName = extractFieldName(from: \TestUser.email)
        #expect(fieldName == "email")
    }

    // MARK: - Multiple Field Extraction

    @Test("Extract multiple fields at once")
    func extractMultipleFields() {
        let fields = [
            \TestUser.name,
            \TestUser.email,
            \TestUser.age
        ]

        let fieldNames = fields.map { extractFieldName(from: $0) }

        #expect(fieldNames == ["name", "email", "age"])
    }

    // MARK: - Edge Cases

    @Test("Extract field with underscores")
    func extractFieldWithUnderscores() {
        struct Model: Codable, Sendable {
            var user_name: String
            var email_address: String
        }

        #expect(extractFieldName(from: \Model.user_name) == "user_name")
        #expect(extractFieldName(from: \Model.email_address) == "email_address")
    }

    @Test("Extract field with numbers")
    func extractFieldWithNumbers() {
        struct Model: Codable, Sendable {
            var field1: String
            var item2: Int
        }

        #expect(extractFieldName(from: \Model.field1) == "field1")
        #expect(extractFieldName(from: \Model.item2) == "item2")
    }

    @Test("Extract single character field")
    func extractSingleCharacterField() {
        struct Model: Codable, Sendable {
            var x: Int
            var y: Int
        }

        #expect(extractFieldName(from: \Model.x) == "x")
        #expect(extractFieldName(from: \Model.y) == "y")
    }
}
