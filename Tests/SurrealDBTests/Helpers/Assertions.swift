@testable import SurrealDB
import Testing

// MARK: - Custom Test Helpers

/// Assert that a RecordID matches expected table and id
func expectRecordID(
    _ recordID: RecordID?,
    table: String,
    id: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let recordID = recordID else {
        Issue.record("RecordID is nil", sourceLocation: sourceLocation)
        return
    }

    #expect(recordID.table == table, "Table mismatch", sourceLocation: sourceLocation)
    #expect(recordID.id == id, "ID mismatch", sourceLocation: sourceLocation)
}

/// Assert that two arrays contain the same elements (order-independent)
func expectArraysEqual<T: Equatable & Hashable>(
    _ array1: [T],
    _ array2: [T],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(Set(array1) == Set(array2), "Arrays are not equal", sourceLocation: sourceLocation)
}

/// Assert that a SurrealError matches expected type
func expectSurrealError(
    _ error: Error,
    matches expected: SurrealError,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let surrealError = error as? SurrealError else {
        Issue.record("Error is not a SurrealError: \(error)", sourceLocation: sourceLocation)
        return
    }

    #expect(surrealError == expected, sourceLocation: sourceLocation)
}
