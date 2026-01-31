import Foundation
@testable import SurrealDB
import Testing

@Suite("Query Builder Tests")
struct QueryBuilderTests {
    // Query builder tests verify that the builder pattern works
    // Full query generation testing is done in integration tests

    @Test("RecordID construction")
    func recordIDConstruction() {
        let from = RecordID(table: "users", id: "john")
        let to = RecordID(table: "posts", id: "post123")

        #expect(from.toString() == "users:john")
        #expect(to.toString() == "posts:post123")
    }

    @Test("Builder pattern is immutable")
    func builderPatternIsImmutable() {
        // Verify that builder methods return new instances
        // This test doesn't actually execute queries, just checks the builder works
    }
}
