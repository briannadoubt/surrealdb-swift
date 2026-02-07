import Foundation
@testable import SurrealDB
import Testing

@Suite("Deferred Backlog Features")
struct DeferredBacklogTests {
    struct DSLUser: SurrealModel {
        var id: RecordID?
        var name: String
        var age: Int
    }

    @Test("Payload codec round-trips JSON-RPC with CBOR")
    func cborPayloadCodecRoundTrip() throws {
        let request = JSONRPCRequest(id: "1", method: "query", params: [.string("SELECT * FROM users")])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try PayloadCodec.encode(request, as: .cbor, using: encoder)
        let decoded = try PayloadCodec.decode(JSONRPCRequest.self, from: encoded, preferred: .cbor, using: decoder)

        #expect(decoded.method == "query")
        #expect(decoded.params != nil)
    }

    @Test("Payload codec falls back to JSON decoding when CBOR preferred")
    func cborDecodeFallsBackToJSON() throws {
        let response = JSONRPCResponse(jsonrpc: "2.0", id: "1", result: .string("ok"), error: nil)
        let jsonData = try JSONEncoder().encode(response)

        let decoded = try PayloadCodec.decode(
            JSONRPCResponse.self,
            from: jsonData,
            preferred: .cbor,
            using: JSONDecoder()
        )

        #expect(decoded.id == "1")
        #expect(decoded.result == .string("ok"))
    }

    @Test("Result-builder query DSL generates typed query")
    func queryDSLBuildsExpectedQuery() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        await transport.queueResponse(
            id: "*",
            result: .array([
                .object([
                    "status": .string("OK"),
                    "result": .array([
                        .object([
                            "name": .string("Alice"),
                            "age": .int(32)
                        ])
                    ])
                ])
            ])
        )

        let users: [DSLUser] = try await db.query(DSLUser.self) {
            Select(\DSLUser.name, \DSLUser.age)
            Where(\DSLUser.age >= 21)
            OrderBy(\DSLUser.name, .descending)
            Limit(5)
            Offset(10)
        }

        #expect(users.count == 1)
        #expect(users.first?.name == "Alice")

        let request = await transport.sentRequests.first
        #expect(request?.method == "query")
        guard let params = request?.params, case .string(let sql) = params.first else {
            Issue.record("Expected query SQL parameter")
            return
        }

        #expect(sql.contains("SELECT name, age FROM dsluser"))
        #expect(sql.contains("WHERE age >="))
        #expect(sql.contains("ORDER BY name DESC"))
        #expect(sql.contains("LIMIT 5"))
        #expect(sql.contains("START 10"))
    }

    @Test("Session is restored after reconnect event")
    func reconnectRestoresSession() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)

        await transport.queueResponse(id: "*", result: .null)

        try await db.connect()
        try await db.authenticate(token: "test-token")
        try await db.use(namespace: "test_ns", database: "test_db")

        let beforeCount = await transport.requestCount()

        await transport.emitConnectionEvent(.reconnected(attempt: 1))
        try await Task.sleep(nanoseconds: 100_000_000)

        let requests = await transport.sentRequests
        #expect(requests.count > beforeCount)

        let methods = requests.map(\.method)
        #expect(methods.filter { $0 == "authenticate" }.count >= 2)
        #expect(methods.filter { $0 == "use" }.count >= 2)
    }

    @Test("TransportConfig enforces minimum pool size")
    func transportConfigPoolSizeMinimum() {
        let config = TransportConfig(httpConnectionPoolSize: 0)
        #expect(config.httpConnectionPoolSize == 1)
    }

    @Test("LocalSurrealDBService provides app-layer SurrealDBService abstraction")
    func surrealDBServiceConformance() async throws {
        let transport = MockTransport()
        let db = SurrealDB(transport: transport)
        let service = LocalSurrealDBService(db: db)

        func roundTrip<DB: SurrealDBService>(_ service: DB) async throws {
            try await service.connect()
            _ = try await service.query("SELECT * FROM users", variables: nil)
            try await service.disconnect()
        }

        try await roundTrip(service)
    }
}
