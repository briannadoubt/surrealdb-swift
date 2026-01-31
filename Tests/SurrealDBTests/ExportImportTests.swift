import Foundation
@testable import SurrealDB
import Testing

@Suite("Export and Import Tests")
struct ExportImportTests {
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
        _ = try encoder.encode(customOptions)
    }

    @Test("Export throws error on WebSocket transport")
    func exportRequiresHTTPTransport() async throws {
        let transport = MockTransport()  // WebSocket mock (default)
        let db = SurrealDB(transport: transport)

        var thrownError: SurrealError?
        do {
            _ = try await db.export()
        } catch let error as SurrealError {
            thrownError = error
        }

        #expect(thrownError != nil)
        if case .unsupportedOperation(let message) = thrownError {
            #expect(message.contains("HTTP"))
            #expect(message.contains("Export") || message.contains("export"))
        } else {
            throw ExportImportTestError.unexpectedError
        }
    }

    @Test("Import throws error on WebSocket transport")
    func importRequiresHTTPTransport() async throws {
        let transport = MockTransport()  // WebSocket mock (default)
        let db = SurrealDB(transport: transport)

        var thrownError: SurrealError?
        do {
            try await db.import("DEFINE TABLE users;")
        } catch let error as SurrealError {
            thrownError = error
        }

        #expect(thrownError != nil)
        if case .unsupportedOperation(let message) = thrownError {
            #expect(message.contains("HTTP"))
            #expect(message.contains("Import") || message.contains("import"))
        } else {
            throw ExportImportTestError.unexpectedError
        }
    }
}

enum ExportImportTestError: Error {
    case unexpectedParameterType
    case unexpectedError
}
