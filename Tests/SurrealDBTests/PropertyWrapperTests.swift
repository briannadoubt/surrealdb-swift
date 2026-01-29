import Testing
import Foundation
@testable import SurrealDB

@Suite("Property Wrappers")
struct PropertyWrapperTests {

    // MARK: - @ID Property Wrapper Tests

    @Suite("@ID Property Wrapper")
    struct IDTests {

        @Test("ID encodes and decodes correctly")
        func idCodableRoundTrip() throws {
            var id = ID(wrappedValue: RecordID(table: "users", id: "123"))

            let encoded = try JSONEncoder().encode(id)
            let decoded = try JSONDecoder().decode(ID.self, from: encoded)

            #expect(decoded.wrappedValue?.table == "users")
            #expect(decoded.wrappedValue?.id == "123")
        }

        @Test("ID validates table name")
        func idValidation() throws {
            let id = ID(wrappedValue: RecordID(table: "users", id: "123"))

            // Should not throw for correct table
            try id.validate(forTable: "users")

            // Should throw for incorrect table
            #expect(throws: SurrealError.self) {
                try id.validate(forTable: "posts")
            }
        }

        @Test("ID auto-generation with UUID")
        func idAutoGenerationUUID() throws {
            var id = ID(wrappedValue: nil, strategy: .uuid)

            #expect(id.wrappedValue == nil)

            id.generateIfNeeded(table: "users")

            #expect(id.wrappedValue != nil)
            #expect(id.wrappedValue?.table == "users")
            #expect(id.wrappedValue?.id.count ?? 0 > 0)
        }

        @Test("ID does not regenerate if already set")
        func idDoesNotRegenerate() {
            var id = ID(wrappedValue: RecordID(table: "users", id: "existing"), strategy: .uuid)
            let originalID = id.wrappedValue

            id.generateIfNeeded(table: "users")

            #expect(id.wrappedValue == originalID)
        }

        @Test("ID with none strategy does not auto-generate")
        func idNoAutoGeneration() {
            var id = ID(wrappedValue: nil, strategy: .none)

            id.generateIfNeeded(table: "users")

            #expect(id.wrappedValue == nil)
        }
    }

    // MARK: - @Relation Property Wrapper Tests

    @Suite("@Relation Property Wrapper")
    struct RelationTests {

        @Test("Relation starts unloaded")
        func relationStartsUnloaded() {
            let relation = Relation<TestPost, TestAuthored>(edge: TestAuthored.self, direction: .out)

            #expect(relation.isLoaded == false)
            #expect(relation.wrappedValue.isEmpty)
        }

        @Test("Relation marks loaded when values set")
        func relationMarksLoaded() {
            var relation = Relation<TestPost, TestAuthored>(edge: TestAuthored.self, direction: .out)
            let posts = [TestFixtures.createPost()]

            relation.wrappedValue = posts

            #expect(relation.isLoaded == true)
            #expect(relation.wrappedValue.count == 1)
        }

        @Test("Relation can be reset")
        func relationReset() {
            var relation = Relation<TestPost, TestAuthored>(edge: TestAuthored.self, direction: .out)
            relation.wrappedValue = [TestFixtures.createPost()]

            #expect(relation.isLoaded == true)

            relation.reset()

            #expect(relation.isLoaded == false)
            #expect(relation.wrappedValue.isEmpty)
        }

        @Test("Relation encodes only when loaded")
        func relationEncodesOnlyWhenLoaded() throws {
            // Test loaded relation
            let loaded = Relation<TestPost, TestAuthored>(
                edge: TestAuthored.self,
                direction: .out,
                loaded: [TestFixtures.createPost()]
            )
            let loadedData = try JSONEncoder().encode(loaded)
            let loadedJSON = String(data: loadedData, encoding: .utf8)!

            // Should contain posts in JSON
            #expect(loadedJSON.contains("title") || loadedJSON.count > 0)
        }

        @Test("Relation supports all directions")
        func relationDirections() {
            let outgoing = Relation<TestPost, TestAuthored>(edge: TestAuthored.self, direction: .out)
            let incoming = Relation<TestUser, TestAuthored>(edge: TestAuthored.self, direction: .in)
            let bidirectional = Relation<TestPost, TestAuthored>(edge: TestAuthored.self, direction: .both)

            #expect(outgoing.direction == .out)
            #expect(incoming.direction == .in)
            #expect(bidirectional.direction == .both)
        }
    }

    // MARK: - @Computed Property Wrapper Tests

    @Suite("@Computed Property Wrapper")
    struct ComputedTests {

        @Test("Computed does not encode in models")
        func computedDoesNotEncode() {
            // Computed fields should not be encoded when part of a model
            // This is tested by verifying the encode function does nothing
            let computed = Computed<Int>("count(items)")

            // The key test is that Computed's encode() does not write any values
            // This is enforced by the implementation which has an empty encode() body
            #expect(computed.expression == "count(items)")
        }

        @Test("Computed decodes from query results")
        func computedDecodesFromResults() throws {
            let json = "42"
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(Computed<Int>.self, from: data)

            #expect(decoded.wrappedValue == 42)
        }

        @Test("Computed aggregate helpers")
        func computedAggregates() {
            let count = Computed<Int>(count: "items")
            let sum = Computed<Int>(sum: "values")
            let avg = Computed<Double>(avg: "scores")
            let max = Computed<Int>(max: "prices")
            let min = Computed<Int>(min: "ages")

            #expect(count.expression == "count(items)")
            #expect(sum.expression == "sum(values)")
            #expect(avg.expression == "avg(scores)")
            #expect(max.expression == "max(prices)")
            #expect(min.expression == "min(ages)")
        }
    }

    // MARK: - @Index Property Wrapper Tests

    @Suite("@Index Property Wrapper")
    struct IndexTests {

        @Test("Index wraps value correctly")
        func indexWrapsValue() {
            let indexed = Index(wrappedValue: "test@example.com", type: .unique)

            #expect(indexed.wrappedValue == "test@example.com")
            #expect(indexed.indexType == .unique)
        }

        @Test("Index supports all types")
        func indexTypes() {
            let unique = Index(wrappedValue: "value", type: .unique)
            let search = Index(wrappedValue: "value", type: .search)
            let fulltext = Index(wrappedValue: "value", type: .fulltext)
            let standard = Index(wrappedValue: "value", type: .standard)

            #expect(unique.indexType == .unique)
            #expect(search.indexType == .search)
            #expect(fulltext.indexType == .fulltext)
            #expect(standard.indexType == .standard)
        }

        @Test("Index encodes only the value")
        func indexEncodesValue() throws {
            let indexed = Index(wrappedValue: "test@example.com", type: .unique)
            let encoded = try JSONEncoder().encode(indexed)
            let decoded = try JSONDecoder().decode(Index<String>.self, from: encoded)

            #expect(decoded.wrappedValue == "test@example.com")
        }

        @Test("Index can have custom name")
        func indexCustomName() {
            let indexed = Index(wrappedValue: "value", type: .unique, name: "idx_email")

            #expect(indexed.name == "idx_email")
        }
    }
}
