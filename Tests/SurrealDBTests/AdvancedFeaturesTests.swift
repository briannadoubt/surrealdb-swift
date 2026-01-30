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
