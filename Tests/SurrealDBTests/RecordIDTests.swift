import XCTest
@testable import SurrealDB

final class RecordIDTests: XCTestCase {
    func testParseSimpleRecordID() throws {
        let recordID = try RecordID(parsing: "users:john")

        XCTAssertEqual(recordID.table, "users")
        XCTAssertEqual(recordID.id, "john")
        XCTAssertEqual(recordID.toString(), "users:john")
    }

    func testParseNumericID() throws {
        let recordID = try RecordID(parsing: "posts:123")

        XCTAssertEqual(recordID.table, "posts")
        XCTAssertEqual(recordID.id, "123")
    }

    func testParseUUIDFormat() throws {
        let uuid = "8c5ccf89-6c3c-4d11-8d7f-9ed5a3b95f6e"
        let recordID = try RecordID(parsing: "users:⟨\(uuid)⟩")

        XCTAssertEqual(recordID.table, "users")
        XCTAssertEqual(recordID.id, "⟨\(uuid)⟩")
    }

    func testParseIDWithColons() throws {
        // IDs can contain colons after the first separator
        let recordID = try RecordID(parsing: "events:2024:01:15")

        XCTAssertEqual(recordID.table, "events")
        XCTAssertEqual(recordID.id, "2024:01:15")
    }

    func testInvalidRecordIDMissingColon() {
        XCTAssertThrowsError(try RecordID(parsing: "users")) { error in
            guard case SurrealError.invalidRecordID = error else {
                XCTFail("Expected invalidRecordID error")
                return
            }
        }
    }

    func testInvalidRecordIDEmptyTable() {
        XCTAssertThrowsError(try RecordID(parsing: ":john")) { error in
            guard case SurrealError.invalidRecordID = error else {
                XCTFail("Expected invalidRecordID error")
                return
            }
        }
    }

    func testInvalidRecordIDEmptyID() {
        XCTAssertThrowsError(try RecordID(parsing: "users:")) { error in
            guard case SurrealError.invalidRecordID = error else {
                XCTFail("Expected invalidRecordID error")
                return
            }
        }
    }

    func testRecordIDCodable() throws {
        let recordID = RecordID(table: "users", id: "john")

        let encoder = JSONEncoder()
        let data = try encoder.encode(recordID)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecordID.self, from: data)

        XCTAssertEqual(decoded, recordID)
    }

    func testRecordIDEquality() {
        let id1 = RecordID(table: "users", id: "john")
        let id2 = RecordID(table: "users", id: "john")
        let id3 = RecordID(table: "users", id: "jane")

        XCTAssertEqual(id1, id2)
        XCTAssertNotEqual(id1, id3)
    }

    func testRecordIDHashable() {
        let id1 = RecordID(table: "users", id: "john")
        let id2 = RecordID(table: "users", id: "john")

        var set = Set<RecordID>()
        set.insert(id1)
        set.insert(id2)

        XCTAssertEqual(set.count, 1)
    }
}
