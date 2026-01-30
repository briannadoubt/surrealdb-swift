import Testing
import Foundation
@testable import SurrealDB

@Suite("SurrealValue Tests")
struct SurrealValueTests {
    @Test("Null value encoding and decoding")
    func nullValue() throws {
        let value: SurrealValue = .null

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        #expect(decoded == .null)
    }

    @Test("Bool value encoding and decoding")
    func boolValue() throws {
        let value: SurrealValue = .bool(true)

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        #expect(decoded == .bool(true))
    }

    @Test("Int value encoding and decoding")
    func intValue() throws {
        let value: SurrealValue = .int(42)

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        #expect(decoded == .int(42))
    }

    @Test("Double value encoding and decoding")
    func doubleValue() throws {
        let value: SurrealValue = .double(3.14)

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        #expect(decoded == .double(3.14))
    }

    @Test("String value encoding and decoding")
    func stringValue() throws {
        let value: SurrealValue = .string("hello")

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        #expect(decoded == .string("hello"))
    }

    @Test("Array value encoding and decoding")
    func arrayValue() throws {
        let value: SurrealValue = .array([.int(1), .string("two"), .bool(true)])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        #expect(decoded == value)
    }

    @Test("Object value encoding and decoding")
    func objectValue() throws {
        let value: SurrealValue = .object([
            "name": .string("John"),
            "age": .int(30),
            "active": .bool(true)
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(SurrealValue.self, from: data)

        #expect(decoded == value)
    }

    @Test("Nested structures encoding and decoding")
    func nestedStructures() throws {
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

        #expect(decoded == value)
    }

    @Test("Array subscript access")
    func arraySubscript() {
        let value: SurrealValue = .array([.int(1), .int(2), .int(3)])

        #expect(value[0] == .int(1))
        #expect(value[1] == .int(2))
        #expect(value[2] == .int(3))
        #expect(value[3] == nil)
    }

    @Test("Object subscript access")
    func objectSubscript() {
        let value: SurrealValue = .object([
            "name": .string("John"),
            "age": .int(30)
        ])

        #expect(value["name"] == .string("John"))
        #expect(value["age"] == .int(30))
        #expect(value["unknown"] == nil)
    }

    @Test("Encodable conversion from custom type")
    func encodableConversion() throws {
        struct User: Codable {
            let name: String
            let age: Int
        }

        let user = User(name: "John", age: 30)
        let value = try SurrealValue(from: user)

        guard case .object(let obj) = value else {
            Issue.record("Expected object")
            return
        }

        #expect(obj["name"] == .string("John"))
        #expect(obj["age"] == .int(30))
    }

    @Test("Decodable conversion to custom type")
    func decodableConversion() throws {
        struct User: Codable, Equatable {
            let name: String
            let age: Int
        }

        let value: SurrealValue = .object([
            "name": .string("John"),
            "age": .int(30)
        ])

        let user: User = try value.decode()

        #expect(user == User(name: "John", age: 30))
    }

    @Test("Literal initializers")
    func literalInitializers() {
        let null: SurrealValue = nil
        let bool: SurrealValue = true
        let int: SurrealValue = 42
        let double: SurrealValue = 3.14
        let string: SurrealValue = "hello"
        let array: SurrealValue = [1, 2, 3]
        let object: SurrealValue = ["key": "value"]

        #expect(null == .null)
        #expect(bool == .bool(true))
        #expect(int == .int(42))
        #expect(double == .double(3.14))
        #expect(string == .string("hello"))
        #expect(array == .array([.int(1), .int(2), .int(3)]))
        #expect(object == .object(["key": .string("value")]))
    }
}
