import Testing
@testable import SurrealDB

// MARK: - Test Helpers

/// Verifies that a throwing closure throws a SurrealError of the specified case
func expectSurrealError(
    _ expectedCase: (SurrealError) -> Bool,
    when operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected SurrealError to be thrown, but no error was thrown")
    } catch let error as SurrealError {
        #expect(expectedCase(error), "Expected different SurrealError case, got: \(error)")
    } catch {
        Issue.record("Expected SurrealError, got: \(error)")
    }
}
