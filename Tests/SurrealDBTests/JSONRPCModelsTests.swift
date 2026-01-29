import Testing
import Foundation
@testable import SurrealDB

@Suite("JSON-RPC Models Tests")
struct JSONRPCModelsTests {
    @Test("JSON-RPC request encoding")
    func jsonrpcRequestEncoding() throws {
        let request = JSONRPCRequest(
            id: "test-123",
            method: "select",
            params: [.string("users")]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["id"] as? String == "test-123")
        #expect(json["method"] as? String == "select")
        #expect(json["params"] != nil)
    }

    @Test("JSON-RPC response decoding")
    func jsonrpcResponseDecoding() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "id": "test-123",
            "result": {"name": "John", "age": 30}
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

        #expect(response.jsonrpc == "2.0")
        #expect(response.id == "test-123")
        #expect(response.result != nil)
        #expect(response.error == nil)
    }

    @Test("JSON-RPC error decoding")
    func jsonrpcErrorDecoding() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "id": "test-123",
            "error": {
                "code": -32600,
                "message": "Invalid request"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

        #expect(response.jsonrpc == "2.0")
        #expect(response.id == "test-123")
        #expect(response.result == nil)
        #expect(response.error != nil)
        #expect(response.error?.code == -32600)
        #expect(response.error?.message == "Invalid request")
    }

    @Test("Live query notification decoding")
    func liveQueryNotificationDecoding() throws {
        let json = """
        {
            "action": "CREATE",
            "result": {"id": "users:john", "name": "John"},
            "id": "query-123"
        }
        """

        let data = json.data(using: .utf8)!
        let notification = try JSONDecoder().decode(LiveQueryNotification.self, from: data)

        #expect(notification.action == .create)
        #expect(notification.result != nil)
        #expect(notification.id == "query-123")
    }

    @Test("Live query action types")
    func liveQueryActionTypes() throws {
        let actions: [(String, LiveQueryAction)] = [
            ("CREATE", .create),
            ("UPDATE", .update),
            ("DELETE", .delete),
            ("CLOSE", .close)
        ]

        for (string, expected) in actions {
            let json = """
            {
                "action": "\(string)",
                "result": null
            }
            """

            let data = json.data(using: .utf8)!
            let notification = try JSONDecoder().decode(LiveQueryNotification.self, from: data)

            #expect(notification.action == expected)
        }
    }

    @Test("JSON Patch encoding")
    func jsonPatchEncoding() throws {
        let patches = [
            JSONPatch.add(path: "/name", value: .string("John")),
            JSONPatch.remove(path: "/age"),
            JSONPatch.replace(path: "/email", value: .string("john@example.com"))
        ]

        let data = try JSONEncoder().encode(patches)
        let decoded = try JSONDecoder().decode([JSONPatch].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].op == .add)
        #expect(decoded[1].op == .remove)
        #expect(decoded[2].op == .replace)
    }
}
