import Foundation
import SurrealDB
// import Trebuchet  // Would import in real usage

/*
 * This example demonstrates how SurrealDB integrates with Trebuchet
 * distributed actors without duplicating the interface.
 */

// MARK: - Protocol-Based Approach

/// Core protocol that both local and distributed implementations conform to
public protocol SurrealDBService: Sendable {
    func connect() async throws
    func disconnect() async throws
    func select<T: Decodable>(_ target: String) async throws -> [T]
    func create<T: Encodable, R: Decodable>(_ target: String, data: T?) async throws -> R
    func query(_ sql: String, variables: [String: SurrealValue]?) async throws -> [SurrealValue]
}

// MARK: - Local Implementation

public actor LocalSurrealDBService: SurrealDBService {
    private let db: SurrealDB

    public init(url: String) async throws {
        self.db = try SurrealDB(url: url)
        try await db.connect()
    }

    public func connect() async throws {
        try await db.connect()
    }

    public func disconnect() async throws {
        try await db.disconnect()
    }

    public func select<T: Decodable>(_ target: String) async throws -> [T] {
        try await db.select(target)
    }

    public func create<T: Encodable, R: Decodable>(_ target: String, data: T?) async throws -> R {
        try await db.create(target, data: data)
    }

    public func query(_ sql: String, variables: [String: SurrealValue]?) async throws -> [SurrealValue] {
        try await db.query(sql, variables: variables)
    }
}

// MARK: - Distributed Implementation (Conceptual)

/*
@Trebuchet
public distributed actor DistributedSurrealDBService: SurrealDBService {
    private let db: SurrealDB

    public init(url: String) async throws {
        self.db = try SurrealDB(url: url)
        try await db.connect()
    }

    public distributed func connect() async throws {
        try await db.connect()
    }

    public distributed func disconnect() async throws {
        try await db.disconnect()
    }

    public distributed func select<T: Decodable>(_ target: String) async throws -> [T] {
        try await db.select(target)
    }

    public distributed func create<T: Encodable, R: Decodable>(_ target: String, data: T?) async throws -> R {
        try await db.create(target, data: data)
    }

    public distributed func query(_ sql: String, variables: [String: SurrealValue]?) async throws -> [SurrealValue] {
        try await db.query(sql, variables: variables)
    }
}
*/

// MARK: - Application Service Using Generic DB

/// A user service that works with any SurrealDBService
public actor UserService<DB: SurrealDBService> {
    private let db: DB

    public struct User: Codable {
        let id: String?
        let name: String
        let email: String
        let age: Int
    }

    public init(db: DB) {
        self.db = db
    }

    public func getAdults() async throws -> [User] {
        let results = try await db.query(
            "SELECT * FROM users WHERE age >= $minAge",
            variables: ["minAge": .int(18)]
        )
        return try results.first?.decode() ?? []
    }

    public func createUser(name: String, email: String, age: Int) async throws -> User {
        let user = User(id: nil, name: name, email: email, age: age)
        return try await db.create("users", data: user)
    }

    public func getUserRecommendations(for userId: String) async throws -> [User] {
        // Complex query using graph relationships
        let query = """
        SELECT * FROM users:\(userId)
            ->follows->users
            ->authored->posts
            <-liked<-users
        LIMIT 10
        """

        return try await db.query(query, variables: nil).first?.decode() ?? []
    }
}

// MARK: - Distributed Application Service (Conceptual)

/*
@Trebuchet
public distributed actor DistributedUserService {
    private let db: DistributedSurrealDBService

    public struct User: Codable {
        let id: String?
        let name: String
        let email: String
        let age: Int
    }

    public init(dbUrl: String) async throws {
        self.db = try await DistributedSurrealDBService(url: dbUrl)
    }

    public distributed func getAdults() async throws -> [User] {
        try await db.query(
            "SELECT * FROM users WHERE age >= $minAge",
            variables: ["minAge": .int(18)]
        ).first?.decode() ?? []
    }

    public distributed func createUser(name: String, email: String, age: Int) async throws -> User {
        let user = User(id: nil, name: name, email: email, age: age)
        return try await db.create("users", data: user)
    }

    public distributed func getUserRecommendations(for userId: String) async throws -> [User] {
        let query = """
        SELECT * FROM users:\(userId)
            ->follows->users
            ->authored->posts
            <-liked<-users
        LIMIT 10
        """

        return try await db.query(query, variables: nil).first?.decode() ?? []
    }
}
*/

// MARK: - Usage Examples

@main
struct TrebuchetIntegrationExample {
    static func main() async throws {
        print("=== Trebuchet Integration Example ===\n")

        // 1. Local usage
        print("1. Local Service:")
        let localDB = try await LocalSurrealDBService(url: "ws://localhost:8000/rpc")
        let localService = UserService(db: localDB)

        let user = try await localService.createUser(
            name: "Alice",
            email: "alice@example.com",
            age: 28
        )
        print("   Created user:", user.name)

        let adults = try await localService.getAdults()
        print("   Found \(adults.count) adults")

        try await localDB.disconnect()

        print("\n2. Distributed Service:")
        print("   (Would use DistributedSurrealDBService)")
        print("   Same API, distributed execution!")

        print("\n3. Benefits:")
        print("   ✅ Single implementation")
        print("   ✅ No code duplication")
        print("   ✅ Local and distributed modes")
        print("   ✅ Type-safe across boundaries")

        print("\n✅ Done!")
    }
}

// MARK: - Advanced: Type-Erased Wrapper

/// Type-erased wrapper for any SurrealDBService
public struct AnySurrealDBService: SurrealDBService {
    private let _connect: () async throws -> Void
    private let _disconnect: () async throws -> Void
    private let _select: (String) async throws -> [Any]
    private let _create: (String, Any?) async throws -> Any
    private let _query: (String, [String: SurrealValue]?) async throws -> [SurrealValue]

    public init<S: SurrealDBService>(_ service: S) {
        self._connect = { try await service.connect() }
        self._disconnect = { try await service.disconnect() }
        self._select = { try await service.select($0) }
        self._create = { target, data in
            if let data = data {
                guard let encodableData = data as? any Encodable else {
                    throw SurrealError.encodingError("Data is not Encodable")
                }
                return try await service.create(target, data: encodableData)
            } else {
                return try await service.create(target, data: nil as String?)
            }
        }
        self._query = { try await service.query($0, variables: $1) }
    }

    public func connect() async throws {
        try await _connect()
    }

    public func disconnect() async throws {
        try await _disconnect()
    }

    public func select<T: Decodable>(_ target: String) async throws -> [T] {
        guard let result = try await _select(target) as? [T] else {
            throw SurrealError.invalidResponse("Expected array of \(T.self)")
        }
        return result
    }

    public func create<T: Encodable, R: Decodable>(_ target: String, data: T?) async throws -> R {
        guard let result = try await _create(target, data) as? R else {
            throw SurrealError.invalidResponse("Expected \(R.self)")
        }
        return result
    }

    public func query(_ sql: String, variables: [String: SurrealValue]?) async throws -> [SurrealValue] {
        try await _query(sql, variables)
    }
}

// MARK: - Summary

/*
 * Integration Strategy Summary:
 *
 * 1. Protocol-Based Architecture
 *    - Define SurrealDBService protocol
 *    - Implement for local actor
 *    - Implement for distributed actor
 *    - No code duplication!
 *
 * 2. Generic Services
 *    - Services accept <DB: SurrealDBService>
 *    - Work with both local and distributed
 *    - Single implementation
 *
 * 3. Type Erasure (Optional)
 *    - Use AnySurrealDBService wrapper
 *    - Hide concrete types
 *    - Maximum flexibility
 *
 * 4. Trebuchet Integration
 *    - @Trebuchet macro on distributed actor
 *    - All methods marked `distributed`
 *    - Automatic serialization
 *    - Same API surface!
 */
