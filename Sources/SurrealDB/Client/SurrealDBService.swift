import Foundation

/// Minimal service contract designed for app-layer composition and distributed wrappers.
///
/// This protocol is intentionally transport-agnostic so it can be used by local actors,
/// distributed actors (e.g. Trebuchet), and test doubles.
public protocol SurrealDBService: Sendable {
    func connect() async throws(SurrealError)
    func disconnect() async throws(SurrealError)

    func signin(_ credentials: Credentials) async throws(SurrealError) -> String
    func authenticate(token: String) async throws(SurrealError)
    func use(namespace: String, database: String) async throws(SurrealError)

    func query(_ sql: String, variables: [String: SurrealValue]?) async throws(SurrealError) -> [SurrealValue]
    func select<T: Decodable & Sendable>(_ target: String) async throws(SurrealError) -> [T]
    func create<T: Encodable & Sendable, R: Decodable & Sendable>(
        _ target: String,
        data: T?
    ) async throws(SurrealError) -> R
    func update<T: Encodable & Sendable, R: Decodable & Sendable>(
        _ target: String,
        data: T?
    ) async throws(SurrealError) -> R
    func delete(_ target: String) async throws(SurrealError)
}

/// Local adapter that exposes `SurrealDB` through the app/distributed service contract.
public actor LocalSurrealDBService: SurrealDBService {
    private let db: SurrealDB

    /// Initialize with an existing SurrealDB client.
    public init(db: SurrealDB) {
        self.db = db
    }

    /// Convenience initializer for app wiring.
    public init(
        url: String,
        config: TransportConfig = .default,
        cachePolicy: CachePolicy? = nil,
        cacheStorage: (any CacheStorage)? = nil
    ) throws(SurrealError) {
        self.db = try SurrealDB(
            url: url,
            config: config,
            cachePolicy: cachePolicy,
            cacheStorage: cacheStorage
        )
    }

    public func connect() async throws(SurrealError) {
        try await db.connect()
    }

    public func disconnect() async throws(SurrealError) {
        try await db.disconnect()
    }

    public func signin(_ credentials: Credentials) async throws(SurrealError) -> String {
        try await db.signin(credentials)
    }

    public func authenticate(token: String) async throws(SurrealError) {
        try await db.authenticate(token: token)
    }

    public func use(namespace: String, database: String) async throws(SurrealError) {
        try await db.use(namespace: namespace, database: database)
    }

    public func query(_ sql: String, variables: [String: SurrealValue]?) async throws(SurrealError) -> [SurrealValue] {
        try await db.query(sql, variables: variables)
    }

    public func select<T: Decodable & Sendable>(_ target: String) async throws(SurrealError) -> [T] {
        try await db.select(target)
    }

    public func create<T: Encodable & Sendable, R: Decodable & Sendable>(
        _ target: String,
        data: T?
    ) async throws(SurrealError) -> R {
        try await db.create(target, data: data)
    }

    public func update<T: Encodable & Sendable, R: Decodable & Sendable>(
        _ target: String,
        data: T?
    ) async throws(SurrealError) -> R {
        try await db.update(target, data: data)
    }

    public func delete(_ target: String) async throws(SurrealError) {
        try await db.delete(target)
    }
}
