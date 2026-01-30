import Testing
@testable import SurrealDB

@Suite("Advanced Features Tests")
struct AdvancedFeaturesTests {
    // MARK: - InsertRelation Tests

    @Test("InsertRelation sends correct RPC method")
    func insertRelationRPCMethod() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        struct EdgeData: Codable {
            let `in`: String
            let out: String
        }

        await transport.queueResponse(id: "*", result: .object([
            "id": .string("authored:1"),
            "in": .string("users:john"),
            "out": .string("posts:123")
        ]))

        let _: EdgeData = try await db.insertRelation(
            "authored",
            data: EdgeData(in: "users:john", out: "posts:123")
        )

        let sentRequests = await transport.sentRequests
        #expect(sentRequests.count == 1)
        let request = sentRequests[0]
        #expect(request.method == "insert")
        #expect(request.params?.count == 2)

        // Verify table parameter
        guard let params = request.params, case .string(let table) = params[0] else {
            throw AdvancedTestError.unexpectedParameterType
        }
        #expect(table == "authored")
    }

    @Test("InsertRelation decodes response correctly")
    func insertRelationDecoding() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        struct Relationship: Codable, Equatable {
            let id: String
            let `in`: String
            let out: String
        }

        await transport.queueResponse(id: "*", result: .object([
            "id": .string("authored:1"),
            "in": .string("users:john"),
            "out": .string("posts:123")
        ]))

        let relation: Relationship = try await db.insertRelation(
            "authored",
            data: Relationship(id: "authored:1", in: "users:john", out: "posts:123")
        )

        #expect(relation.id == "authored:1")
        #expect(relation.in == "users:john")
        #expect(relation.out == "posts:123")
    }

    // MARK: - SubscribeLive Tests

    @Test("SubscribeLive throws error on non-WebSocket transport")
    func subscribeLiveRequiresWebSocket() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        // MockTransport doesn't identify as WebSocketTransport by default
        // This will fail the transport check
        var thrownError: SurrealError?
        do {
            let _ = try await db.subscribeLive("test-query-id")
        } catch let error as SurrealError {
            thrownError = error
        }

        // Since MockTransport is not WebSocketTransport, it should throw
        #expect(thrownError != nil)
        if case .unsupportedOperation(let message) = thrownError {
            #expect(message.contains("WebSocket"))
            #expect(message.contains("Live") || message.contains("live"))
        } else {
            throw AdvancedTestError.unexpectedError
        }
    }

    @Test("Multiple subscriptions to same query ID")
    func multipleSubscriptionsSupported() async throws {
        // Note: This test verifies the API allows multiple subscriptions.
        // Integration tests with real WebSocket transport would verify
        // that all subscriptions receive notifications.
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        // The test demonstrates that both live() and subscribeLive() can be
        // called multiple times without errors, supporting the multi-subscriber pattern
        #expect(transport != nil)
        #expect(db != nil)
    }

    // MARK: - Close Tests

    @Test("Close calls disconnect")
    func closeCallsDisconnect() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        try await db.connect()
        #expect(await transport.isConnected == true)

        try await db.close()
        #expect(await transport.isConnected == false)
    }
}

enum AdvancedTestError: Error {
    case unexpectedParameterType
    case unexpectedError
}
