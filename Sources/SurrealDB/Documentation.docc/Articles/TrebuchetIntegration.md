# Trebuchet Integration

Use `SurrealDBService` as the app-facing contract so your business logic works in both local and distributed runtimes.

## Why this pattern

- Local app code can use `SurrealDB` directly
- Trebuchet distributed actors can wrap `SurrealDB` behind the same interface
- Repositories/services stay unchanged across deployment modes

## 1. Build app code against `SurrealDBService`

```swift
import SurrealDB

actor UserRepository<DB: SurrealDBService> {
    private let db: DB

    init(db: DB) {
        self.db = db
    }

    func initialize() async throws {
        _ = try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "app", database: "main")
    }

    func adults() async throws -> [User] {
        let rows = try await db.query(
            "SELECT * FROM users WHERE age >= $minAge",
            variables: ["minAge": .int(18)]
        )
        return try rows.first?.decode() ?? []
    }
}
```

## 2. Local wiring

```swift
let db = try LocalSurrealDBService(
    url: "ws://localhost:8000/rpc",
    config: TransportConfig(
        payloadEncoding: .json,
        reconnectionPolicy: .exponentialBackoff(),
        httpConnectionPoolSize: 8
    )
)

let repo = UserRepository(db: db)
```

## 3. Trebuchet distributed wiring

```swift
import Trebuchet
import SurrealDB

@Trebuchet
public distributed actor DistributedSurrealDBService: SurrealDBService {
    private let db: SurrealDB

    public init(url: String) throws {
        self.db = try SurrealDB(url: url)
    }

    public distributed func connect() async throws(SurrealError) { try await db.connect() }
    public distributed func disconnect() async throws(SurrealError) { try await db.disconnect() }
    public distributed func signin(_ credentials: Credentials) async throws(SurrealError) -> String { try await db.signin(credentials) }
    public distributed func authenticate(token: String) async throws(SurrealError) { try await db.authenticate(token: token) }
    public distributed func use(namespace: String, database: String) async throws(SurrealError) { try await db.use(namespace: namespace, database: database) }
    public distributed func query(_ sql: String, variables: [String: SurrealValue]?) async throws(SurrealError) -> [SurrealValue] { try await db.query(sql, variables: variables) }
    public distributed func select<T: Decodable>(_ target: String) async throws(SurrealError) -> [T] { try await db.select(target) }
    public distributed func create<T: Encodable, R: Decodable>(_ target: String, data: T?) async throws(SurrealError) -> R { try await db.create(target, data: data) }
    public distributed func update<T: Encodable, R: Decodable>(_ target: String, data: T?) async throws(SurrealError) -> R { try await db.update(target, data: data) }
    public distributed func delete(_ target: String) async throws(SurrealError) { try await db.delete(target) }
}
```

## Operational notes

- Keep integration tests local-only with `SURREALDB_TEST=1`
- Use `TransportConfig.logger` and `TransportConfig.metrics` for distributed observability
- Reconnection session restore (auth + namespace/database) is built into `SurrealDB` after reconnect events
