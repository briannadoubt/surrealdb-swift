import Foundation
import SurrealDB

/*
 Trebuchet integration example for app architecture.

 This file shows a practical pattern:
 1) App code depends on `SurrealDBService`.
 2) Local mode uses `SurrealDB` directly.
 3) Trebuchet mode wraps `SurrealDB` in a distributed actor.
*/

// MARK: - App Model

struct AppUser: Codable, Sendable {
    let id: String?
    let name: String
    let email: String
    let age: Int
}

// MARK: - App Service Layer

/// Business logic depends on protocol, not concrete transport/runtime.
actor UserRepository<DB: SurrealDBService> {
    private let db: DB

    init(db: DB) {
        self.db = db
    }

    func initialize() async throws {
        _ = try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "app", database: "main")
    }

    func createUser(name: String, email: String, age: Int) async throws -> AppUser {
        try await db.create("users", data: AppUser(id: nil, name: name, email: email, age: age))
    }

    func adults() async throws -> [AppUser] {
        let rows = try await db.query(
            "SELECT * FROM users WHERE age >= $minAge ORDER BY age",
            variables: ["minAge": .int(18)]
        )

        guard let first = rows.first else {
            return []
        }

        if case .object(let object) = first,
           let result = object["result"],
           case .array(let values) = result {
            return try values.map { try $0.safelyDecode() }
        }

        return []
    }
}

// MARK: - Local Wiring

func makeLocalRepository(url: String) throws -> UserRepository<LocalSurrealDBService> {
    let db = try LocalSurrealDBService(
        url: url,
        config: TransportConfig(
            requestTimeout: 30,
            connectionTimeout: 10,
            payloadEncoding: .json,
            reconnectionPolicy: .exponentialBackoff(),
            httpConnectionPoolSize: 8
        )
    )

    return UserRepository(db: db)
}

// MARK: - Trebuchet Wiring (example)

/*
#if canImport(Trebuchet)
import Trebuchet

@Trebuchet
public distributed actor DistributedSurrealDBService: SurrealDBService {
    private let db: SurrealDB

    public init(url: String) throws {
        self.db = try SurrealDB(url: url)
    }

    public distributed func connect() async throws(SurrealError) {
        try await db.connect()
    }

    public distributed func disconnect() async throws(SurrealError) {
        try await db.disconnect()
    }

    public distributed func signin(_ credentials: Credentials) async throws(SurrealError) -> String {
        try await db.signin(credentials)
    }

    public distributed func authenticate(token: String) async throws(SurrealError) {
        try await db.authenticate(token: token)
    }

    public distributed func use(namespace: String, database: String) async throws(SurrealError) {
        try await db.use(namespace: namespace, database: database)
    }

    public distributed func query(
        _ sql: String,
        variables: [String: SurrealValue]?
    ) async throws(SurrealError) -> [SurrealValue] {
        try await db.query(sql, variables: variables)
    }

    public distributed func select<T: Decodable>(
        _ target: String
    ) async throws(SurrealError) -> [T] {
        try await db.select(target)
    }

    public distributed func create<T: Encodable, R: Decodable>(
        _ target: String,
        data: T?
    ) async throws(SurrealError) -> R {
        try await db.create(target, data: data)
    }

    public distributed func update<T: Encodable, R: Decodable>(
        _ target: String,
        data: T?
    ) async throws(SurrealError) -> R {
        try await db.update(target, data: data)
    }

    public distributed func delete(_ target: String) async throws(SurrealError) {
        try await db.delete(target)
    }
}

func makeDistributedRepository(url: String) async throws -> UserRepository<DistributedSurrealDBService> {
    let distributed = try DistributedSurrealDBService(url: url)
    return UserRepository(db: distributed)
}
#endif
*/
