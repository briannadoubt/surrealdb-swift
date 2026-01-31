@testable import SurrealDB
import Testing

@Suite("Error Handling")
struct ErrorHandlingTests {
    // MARK: - SurrealError Tests

    @Test("SurrealError connection error")
    func connectionError() {
        let error = SurrealError.connectionError("Failed to connect")

        #expect(error == SurrealError.connectionError("Failed to connect"))
        #expect(error.description.contains("Connection"))
    }

    @Test("SurrealError RPC error")
    func rpcError() {
        let error = SurrealError.rpcError(code: 500, message: "Internal error", data: nil)

        #expect(error == SurrealError.rpcError(code: 500, message: "Internal error", data: nil))
        #expect(error.description.contains("500"))
        #expect(error.description.contains("Internal error"))
    }

    @Test("SurrealError authentication error")
    func authenticationError() {
        let error = SurrealError.authenticationError("Invalid credentials")

        #expect(error == SurrealError.authenticationError("Invalid credentials"))
        #expect(error.description.contains("Authentication"))
    }

    @Test("SurrealError timeout")
    func timeout() {
        let error = SurrealError.timeout

        #expect(error == SurrealError.timeout)
        #expect(error.description.contains("timed out"))
    }

    @Test("SurrealError invalid response")
    func invalidResponse() {
        let error = SurrealError.invalidResponse("Unexpected format")

        #expect(error == SurrealError.invalidResponse("Unexpected format"))
        #expect(error.description.contains("Invalid response"))
    }

    @Test("SurrealError transport closed")
    func transportClosed() {
        let error = SurrealError.transportClosed

        #expect(error == SurrealError.transportClosed)
        #expect(error.description.contains("closed"))
    }

    @Test("SurrealError invalid record ID")
    func invalidRecordID() {
        let error = SurrealError.invalidRecordID("Malformed ID")

        #expect(error == SurrealError.invalidRecordID("Malformed ID"))
        #expect(error.description.contains("Invalid record ID"))
    }

    @Test("SurrealError not connected")
    func notConnected() {
        let error = SurrealError.notConnected

        #expect(error == SurrealError.notConnected)
        #expect(error.description.contains("Not connected"))
    }

    @Test("SurrealError encoding error")
    func encodingError() {
        let error = SurrealError.encodingError("Failed to encode data")

        #expect(error == SurrealError.encodingError("Failed to encode data"))
        #expect(error.description.contains("Encoding error"))
    }

    @Test("SurrealError unsupported operation")
    func unsupportedOperation() {
        let error = SurrealError.unsupportedOperation("Live queries not supported on HTTP")

        #expect(error == SurrealError.unsupportedOperation("Live queries not supported on HTTP"))
        #expect(error.description.contains("Unsupported"))
    }

    // MARK: - Error Equatable Tests

    @Test("Errors with same type and message are equal")
    func errorEquality() {
        let error1 = SurrealError.connectionError("Test")
        let error2 = SurrealError.connectionError("Test")

        #expect(error1 == error2)
    }

    @Test("Errors with different messages are not equal")
    func errorInequality() {
        let error1 = SurrealError.connectionError("Test1")
        let error2 = SurrealError.connectionError("Test2")

        #expect(error1 != error2)
    }

    @Test("Different error types are not equal")
    func differentErrorTypes() {
        let error1 = SurrealError.timeout
        let error2 = SurrealError.transportClosed

        #expect(error1 != error2)
    }

    // MARK: - RecordID Error Tests

    @Test("RecordID parsing errors")
    func recordIDParsingErrors() {
        do {
            _ = try RecordID(parsing: "invalid")
            Issue.record("Should have thrown for invalid format")
        } catch {
            // Expected
        }

        do {
            _ = try RecordID(parsing: "")
            Issue.record("Should have thrown for empty string")
        } catch {
            // Expected
        }
    }

    @Test("RecordID validation errors")
    func recordIDValidationErrors() {
        let id = ID(wrappedValue: RecordID(table: "users", id: "123"))

        #expect(throws: SurrealError.self) {
            try id.validate(forTable: "posts")
        }
    }
}
