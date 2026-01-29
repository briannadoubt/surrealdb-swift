import XCTest
@testable import SurrealDB

final class SurrealValueTests: XCTestCase {
    func testNullValue() throws {
        let value: SurrealValue = .null

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, .null)
    }

    func testBoolValue() throws {
        let value: SurrealValue = .bool(true)

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, .bool(true))
    }

    func testIntValue() throws {
        let value: SurrealValue = .int(42)

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, .int(42))
    }

    func testDoubleValue() throws {
        let value: SurrealValue = .double(3.14)

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, .double(3.14))
    }

    func testStringValue() throws {
        let value: SurrealValue = .string("hello")

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, .string("hello"))
    }

    func testArrayValue() throws {
        let value: SurrealValue = .array([.int(1), .string("two"), .bool(true)])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, value)
    }

    func testObjectValue() throws {
        let value: SurrealValue = .object([
            "name": .string("John"),
            "age": .int(30),
            "active": .bool(true)
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, value)
    }

    func testNestedStructures() throws {
        let value: SurrealValue = .object([
            "user": .object([
                "name": .string("John"),
                "tags": .array([.string("admin"), .string("user")])
            ]),
            "posts": .array([
                .object(["title": .string("Post 1")]),
                .object(["title": .string("Post 2")])
            ])
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        XCTAssertEqual(decoded, value)
    }

    func testArraySubscript() {
        let value: SurrealValue = .array([.int(1), .int(2), .int(3)])

        XCTAssertEqual(value[0], .int(1))
        XCTAssertEqual(value[1], .int(2))
        XCTAssertEqual(value[2], .int(3))
        XCTAssertNil(value[3])
    }

    func testObjectSubscript() {
        let value: SurrealValue = .object([
            "name": .string("John"),
            "age": .int(30)
        ])

        XCTAssertEqual(value["name"], .string("John"))
        XCTAssertEqual(value["age"], .int(30))
        XCTAssertNil(value["unknown"])
    }

    func testEncodableConversion() throws {
        struct User: Codable {
            let name: String
            let age: Int
        }

        let user = User(name: "John", age: 30)
        let value = try SurrealValue(from: user)

        guard case .object(let obj) = value else {
            XCTFail("Expected object")
            return
        }

        XCTAssertEqual(obj["name"], .string("John"))
        XCTAssertEqual(obj["age"], .int(30))
    }

    func testDecodableConversion() throws {
        struct User: Codable, Equatable {
            let name: String
            let age: Int
        }

        let value: SurrealValue = .object([
            "name": .string("John"),
            "age": .int(30)
        ])

        let user: User = try value.decode()

        XCTAssertEqual(user, User(name: "John", age: 30))
    }

    func testLiteralInitializers() {
        let null: SurrealValue = nil
        let bool: SurrealValue = true
        let int: SurrealValue = 42
        let double: SurrealValue = 3.14
        let string: SurrealValue = "hello"
        let array: SurrealValue = [1, 2, 3]
        let object: SurrealValue = ["key": "value"]

        XCTAssertEqual(null, .null)
        XCTAssertEqual(bool, .bool(true))
        XCTAssertEqual(int, .int(42))
        XCTAssertEqual(double, .double(3.14))
        XCTAssertEqual(string, .string("hello"))
        XCTAssertEqual(array, .array([.int(1), .int(2), .int(3)]))
        XCTAssertEqual(object, .object(["key": .string("value")]))
    }
}
