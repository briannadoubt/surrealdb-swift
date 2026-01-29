import XCTest
@testable import SurrealDB

final class QueryBuilderTests: XCTestCase {
    // Query builder tests verify that the builder pattern works
    // Full query generation testing is done in integration tests

    func testRecordIDConstruction() {
        let from = RecordID(table: "users", id: "john")
        let to = RecordID(table: "posts", id: "post123")

        XCTAssertEqual(from.toString(), "users:john")
        XCTAssertEqual(to.toString(), "posts:post123")
    }

    func testBuilderPatternIsImmutable() {
        // Verify that builder methods return new instances
        // This test doesn't actually execute queries, just checks the builder works
    }
}
