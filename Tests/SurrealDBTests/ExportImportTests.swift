import Testing
import Foundation
@testable import SurrealDB

@Suite("Export and Import Tests")
struct ExportImportTests {
    // Note: Export/import transport type checking is tested in integration tests.
    // These unit tests verify the RPC methods are correctly formed.

    @Test("Export options encode correctly")
    func exportOptionsEncoding() throws {
        let defaultOptions = ExportOptions.default
        #expect(defaultOptions.tables == nil)
        #expect(defaultOptions.functions == true)

        let customOptions = ExportOptions(tables: ["users", "posts"], functions: false)
        #expect(customOptions.tables == ["users", "posts"])
        #expect(customOptions.functions == false)

        // Verify it's encodable
        let encoder = JSONEncoder()
        let _ = try encoder.encode(customOptions)
    }
}

enum ExportImportTestError: Error {
    case unexpectedParameterType
    case unexpectedError
}
