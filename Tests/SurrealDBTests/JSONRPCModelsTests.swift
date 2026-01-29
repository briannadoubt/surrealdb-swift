import XCTest
@testable import SurrealDB

final class JSONRPCModelsTests: XCTestCase {
    func testJSONRPCRequestEncoding() throws {
        let request = JSONRPCRequest(
            id: "test-123",
            method: "select",
            params: [.string("users")]
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json["id"] as? String, "test-123")
        XCTAssertEqual(json["method"] as? String, "select")
        XCTAssertNotNil(json["params"])
    }

    func testJSONRPCResponseDecoding() throws {
        let json = """
        {
            "jsonrpc": "2.0",
            "id": "test-123",
            "result": {"name": "John", "age": 30}
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, "test-123")
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)
    }

    func testJSONRPCErrorDecoding() throws {
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

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, "test-123")
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32600)
        XCTAssertEqual(response.error?.message, "Invalid request")
    }

    func testLiveQueryNotificationDecoding() throws {
        let json = """
        {
            "action": "CREATE",
            "result": {"id": "users:john", "name": "John"},
            "id": "query-123"
        }
        """

        let data = json.data(using: .utf8)!
        let notification = try JSONDecoder().decode(LiveQueryNotification.self, from: data)

        XCTAssertEqual(notification.action, .create)
        XCTAssertNotNil(notification.result)
        XCTAssertEqual(notification.id, "query-123")
    }

    func testLiveQueryActionTypes() throws {
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

            XCTAssertEqual(notification.action, expected)
        }
    }

    func testJSONPatchEncoding() throws {
        let patches = [
            JSONPatch.add(path: "/name", value: .string("John")),
            JSONPatch.remove(path: "/age"),
            JSONPatch.replace(path: "/email", value: .string("john@example.com"))
        ]

        let data = try JSONEncoder().encode(patches)
        let decoded = try JSONDecoder().decode([JSONPatch].self, from: data)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].op, .add)
        XCTAssertEqual(decoded[1].op, .remove)
        XCTAssertEqual(decoded[2].op, .replace)
    }
}
