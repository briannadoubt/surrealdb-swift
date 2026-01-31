import Foundation
@testable import SurrealDB
import Testing

@Suite("RecordID")
struct RecordIDTests {
    @Test("Parse simple RecordID")
    func parseSimpleRecordID() throws {
        let recordID = try RecordID(parsing: "users:john")

        #expect(recordID.table == "users")
        #expect(recordID.id == "john")
        #expect(recordID.toString() == "users:john")
    }

    @Test("Parse numeric ID")
    func parseNumericID() throws {
        let recordID = try RecordID(parsing: "posts:123")

        #expect(recordID.table == "posts")
        #expect(recordID.id == "123")
    }

    @Test("Parse UUID format")
    func parseUUIDFormat() throws {
        let uuid = "8c5ccf89-6c3c-4d11-8d7f-9ed5a3b95f6e"
        let recordID = try RecordID(parsing: "users:⟨\(uuid)⟩")

        #expect(recordID.table == "users")
        #expect(recordID.id == "⟨\(uuid)⟩")
    }

    @Test("Parse ID with colons")
    func parseIDWithColons() throws {
        // IDs can contain colons after the first separator
        let recordID = try RecordID(parsing: "events:2024:01:15")

        #expect(recordID.table == "events")
        #expect(recordID.id == "2024:01:15")
    }

    @Test("Invalid RecordID - missing colon")
    func invalidRecordIDMissingColon() {
        expectSurrealError({ if case .invalidRecordID = $0 { return true } else { return false } }, when: {
            try RecordID(parsing: "users")
        })
    }

    @Test("Invalid RecordID - empty table")
    func invalidRecordIDEmptyTable() {
        expectSurrealError({ if case .invalidRecordID = $0 { return true } else { return false } }, when: {
            try RecordID(parsing: ":john")
        })
    }

    @Test("Invalid RecordID - empty ID")
    func invalidRecordIDEmptyID() {
        expectSurrealError({ if case .invalidRecordID = $0 { return true } else { return false } }, when: {
            try RecordID(parsing: "users:")
        })
    }

    @Test("RecordID is Codable")
    func recordIDCodable() throws {
        let recordID = RecordID(table: "users", id: "john")

        let encoder = JSONEncoder()
        let data = try encoder.encode(recordID)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecordID.self, from: data)

        #expect(decoded == recordID)
    }

    @Test("RecordID equality")
    func recordIDEquality() {
        let id1 = RecordID(table: "users", id: "john")
        let id2 = RecordID(table: "users", id: "john")
        let id3 = RecordID(table: "users", id: "jane")

        #expect(id1 == id2)
        #expect(id1 != id3)
    }

    @Test("RecordID is Hashable")
    func recordIDHashable() {
        let id1 = RecordID(table: "users", id: "john")
        let id2 = RecordID(table: "users", id: "john")

        var set = Set<RecordID>()
        set.insert(id1)
        set.insert(id2)

        #expect(set.count == 1)
    }
}
