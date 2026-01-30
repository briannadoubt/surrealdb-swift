import Testing
@testable import SurrealDB

@Suite("Upsert Tests")
struct UpsertTests {
    @Test("Upsert sends correct RPC method")
    func upsertRPCMethod() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        struct TestData: Codable {
            let name: String
            let age: Int
        }

        // Queue a successful response with wildcard ID
        await transport.queueResponse(id: "*", result: .object([
            "id": .string("users:test"),
            "name": .string("Test User"),
            "age": .int(25)
        ]))

        let _: TestData = try await db.upsert("users:test", data: TestData(name: "Test User", age: 25))

        // Verify the RPC call
        let sentRequests = await transport.sentRequests
        #expect(sentRequests.count == 1)
        let request = sentRequests[0]
        #expect(request.method == "upsert")
        #expect(request.params?.count == 2)

        // Verify target parameter
        guard let params = request.params, case .string(let target) = params[0] else {
            throw TestError.unexpectedParameterType
        }
        #expect(target == "users:test")
    }

    @Test("Upsert with table name")
    func upsertTableName() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        struct TestData: Codable {
            let name: String
            let age: Int
        }

        // Queue a successful response with array
        await transport.queueResponse(id: "*", result: .array([
            .object([
                "id": .string("users:1"),
                "name": .string("User 1"),
                "age": .int(30)
            ])
        ]))

        let _: [TestData] = try await db.upsert("users", data: TestData(name: "User 1", age: 30))

        // Verify the RPC call
        let sentRequests = await transport.sentRequests
        #expect(sentRequests.count == 1)
        let request = sentRequests[0]
        #expect(request.method == "upsert")

        // Verify target is table name
        guard let params = request.params, case .string(let target) = params[0] else {
            throw TestError.unexpectedParameterType
        }
        #expect(target == "users")
    }

    @Test("Upsert decodes response correctly")
    func upsertDecoding() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        struct User: Codable, Equatable {
            let id: String
            let name: String
            let age: Int
        }

        await transport.queueResponse(id: "*", result: .object([
            "id": .string("users:john"),
            "name": .string("John Doe"),
            "age": .int(30)
        ]))

        let user: User = try await db.upsert("users:john", data: User(id: "users:john", name: "John Doe", age: 30))

        #expect(user.id == "users:john")
        #expect(user.name == "John Doe")
        #expect(user.age == 30)
    }
}

enum TestError: Error {
    case unexpectedParameterType
}
