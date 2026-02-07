# SurrealDB Swift

A native Swift client for [SurrealDB](https://surrealdb.com), the ultimate multi-model database.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS%20|%20Linux-blue.svg)](https://swift.org)

## Features

- ✅ **WebSocket & HTTP transports** - Choose the right transport for your needs
- ✅ **Type-safe operations** - Leverage Swift's Codable for automatic encoding/decoding
- ✅ **Real-time live queries** - Subscribe to database changes in real-time
- ✅ **Fluent query builder** - Build SurrealQL queries with a type-safe API
- ✅ **SQL injection prevention** - Automatic parameter binding for all queries
- ✅ **Automatic reconnection** - Configurable exponential backoff on connection loss
- ✅ **Payload encoding options** - JSON (default) or CBOR transport payloads
- ✅ **HTTP connection pooling** - Configurable max connections per host
- ✅ **Observability hooks** - Plug in your logger and metrics recorder
- ✅ **Timeout configuration** - Fine-grained control over request and connection timeouts
- ✅ **Full SurrealQL support** - Execute any SurrealQL query directly
- ✅ **Swift 6 concurrency** - Built with modern Swift concurrency from the ground up
- ✅ **Cross-platform** - Supports all Apple platforms and Linux

## Requirements

- Swift 6.0+
- macOS 14.0+ / iOS 17.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+ / Linux
- SurrealDB 2.0+

## Installation

### Swift Package Manager

Add SurrealDB to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/briannadoubt/surrealdb-swift.git", branch: "main")
]
```

Or in Xcode: File → Add Package Dependencies → Enter repository URL

## Quick Start

```swift
import SurrealDB

// Create and connect
let db = try SurrealDB(url: "ws://localhost:8000/rpc")
try await db.connect()

// Authenticate
try await db.signin(.root(RootAuth(username: "root", password: "root")))
try await db.use(namespace: "test", database: "test")

// Define your model
struct User: Codable {
    let id: String?
    let name: String
    let email: String
    let age: Int
}

// Create a record
let newUser = User(id: nil, name: "John Doe", email: "john@example.com", age: 30)
let created: User = try await db.create("users", data: newUser)

// Query records
let users: [User] = try await db.select("users")

// Use the query builder with type-safe parameter binding
let adults: [User] = try await db
    .query()
    .select("name", "email")
    .from("users")
    .where(field: "age", op: .greaterThanOrEqual, value: .int(18))
    .orderBy("name")
    .limit(10)
    .fetch()

// Real-time live queries
let (queryId, stream) = try await db.live("users")

Task {
    for await notification in stream {
        switch notification.action {
        case .create:
            print("New user:", notification.result)
        case .update:
            print("Updated user:", notification.result)
        case .delete:
            print("Deleted user:", notification.result)
        case .close:
            break
        }
    }
}

// Clean up
try await db.disconnect()
```

## Configuration & Security

### Timeout and Reconnection

Configure timeouts and automatic reconnection:

```swift
let config = TransportConfig(
    requestTimeout: 30.0,      // 30 seconds per request
    connectionTimeout: 10.0,   // 10 seconds to establish connection
    payloadEncoding: .json,    // or .cbor
    httpConnectionPoolSize: 8, // max HTTP connections per host
    reconnectionPolicy: .exponentialBackoff(
        initialDelay: 1.0,
        maxDelay: 60.0,
        multiplier: 2.0,
        maxAttempts: 10
    )
)

let db = try SurrealDB(url: "wss://production.example.com/rpc", config: config)
```

### Reconnection Policies

```swift
// Never reconnect
.reconnectionPolicy = .never

// Constant delay between attempts
.reconnectionPolicy = .constant(delay: 5.0, maxAttempts: 5)

// Exponential backoff (recommended for production)
.reconnectionPolicy = .exponentialBackoff()

// Always reconnect (use with caution)
.reconnectionPolicy = .alwaysReconnect()
```

### Security Best Practices

All query values are automatically parameterized to prevent SQL injection:

```swift
// ✅ SAFE: User input is automatically parameterized
let username = getUserInput()
let user: User? = try await db.query()
    .select("*")
    .from("users")
    .where(field: "username", op: .equal, value: .string(username))
    .fetchOne()
```

**Production Checklist**:
- ✅ Always use secure transports (`wss://`, `https://`) in production
- ✅ Configure appropriate timeouts for your use case
- ✅ Enable automatic reconnection for reliability
- ✅ Never disable TLS verification
- ✅ Use environment-specific configurations

See [Security.md](./Sources/SurrealDB/Documentation.docc/Articles/Security.md) for comprehensive security guidelines.

## Client-Side Caching

### Overview

SurrealDB Swift includes built-in client-side caching to reduce database load and improve application performance. The cache uses intelligent invalidation based on table mutations and supports multiple storage backends.

### Cache Policies

```swift
// Default policy: cache reads, invalidate on writes
let db = try SurrealDB(
    url: "ws://localhost:8000/rpc",
    cachePolicy: .default
)

// Custom policy: aggressive caching with TTL
let db = try SurrealDB(
    url: "ws://localhost:8000/rpc",
    cachePolicy: CachePolicy(
        shouldCache: { method, _ in ["select", "query"].contains(method) },
        shouldInvalidate: { method, _ in ["create", "update", "delete"].contains(method) },
        defaultTTL: 300.0,  // 5 minutes
        maxEntries: 1000
    )
)

// Disable caching
let db = try SurrealDB(url: "ws://localhost:8000/rpc", cachePolicy: .disabled)
```

## Trebuchet App Integration

Use the built-in `SurrealDBService` protocol as your app-facing boundary. Local mode uses `LocalSurrealDBService` (adapter over `SurrealDB`), and distributed mode can expose a Trebuchet actor with the same API.

- App-side contract: `SurrealDBService`
- Local concrete type: `LocalSurrealDBService` (wraps `SurrealDB`)
- Distributed concrete type: your `@Trebuchet distributed actor` wrapper delegating to `SurrealDB`

See:
- `/Users/bri/dev/surrealdb-swift/Examples/TrebuchetIntegration.swift`
- `/Users/bri/dev/surrealdb-swift/Sources/SurrealDB/Documentation.docc/Articles/TrebuchetIntegration.md`

### Storage Backends

#### In-Memory (Default)

Works on all platforms including WASM. Data is lost on app restart.

```swift
let db = try SurrealDB(
    url: "ws://localhost:8000/rpc",
    cachePolicy: .default,
    cacheStorage: InMemoryCacheStorage()
)
```

#### Persistent Cache (Apple Platforms / Linux)

Uses GRDB (SQLite) for persistent caching across app restarts.

```swift
import SurrealDBGRDB

let storage = try GRDBCacheStorage(path: "path/to/cache.db")
let db = try SurrealDB(
    url: "ws://localhost:8000/rpc",
    cachePolicy: .default,
    cacheStorage: storage
)
```

#### localStorage Cache (WASM / Browser)

Uses browser localStorage for persistent caching across page reloads.

```swift
#if os(WASM)
import SurrealDBLocalStorage

let storage = LocalStorageCacheStorage(prefix: "surrealdb_cache_")
let db = try SurrealDB(
    url: "ws://localhost:8000/rpc",
    cachePolicy: .default,
    cacheStorage: storage
)
#endif
```

**Browser Storage Limits**: localStorage typically has a 5-10MB quota per origin. Consider implementing eviction strategies if approaching limits.

**Security Considerations**: Data in localStorage is visible in browser developer tools and accessible to all scripts from the same origin.

### Manual Cache Control

```swift
// Check if a query would be cached
let isCached = await db.isCached(key: .select("users"))

// Manually invalidate cache entries
await db.invalidateCache(forTable: "users")

// Clear all cache
await db.clearCache()
```

## Documentation

Browse the full documentation online:

📚 **[Documentation Site](https://briannadoubt.github.io/surrealdb-swift/documentation/surrealdb/)**

Or generate locally:

```bash
# Build documentation
swift package generate-documentation --target SurrealDB

# Preview documentation locally
swift package --disable-sandbox preview-documentation --target SurrealDB
```

## Examples

### Authentication

```swift
// Root authentication
try await db.signin(.root(RootAuth(username: "root", password: "root")))

// Namespace authentication
try await db.signin(.namespace(
    NamespaceAuth(namespace: "myapp", username: "admin", password: "secret")
))

// Database authentication
try await db.signin(.database(
    DatabaseAuth(namespace: "myapp", database: "prod", username: "user", password: "secret")
))

// Record access (user signup/signin)
try await db.signup(
    RecordAccessAuth(
        namespace: "myapp",
        database: "prod",
        access: "user",
        variables: [
            "email": .string("user@example.com"),
            "pass": .string("password123")
        ]
    )
)
```

### CRUD Operations

```swift
// Create
let user: User = try await db.create("users", data: newUser)

// Read
let users: [User] = try await db.select("users")
let user: User = try await db.select("users:john")

// Update
let updated: User = try await db.update("users:john", data: updates)

// Upsert (create or update)
let user: User = try await db.upsert("users:john", data: userData)

// Merge
let merged: User = try await db.merge("users:john", data: partialUpdates)

// Patch
let patched: User = try await db.patch("users:john", patches: [
    .replace(path: "/age", value: .int(31))
])

// Delete
try await db.delete("users:john")
```

### Custom Queries

```swift
let results = try await db.query("""
    SELECT * FROM users
    WHERE age > $minAge
    ORDER BY name
    LIMIT 10
""", variables: ["minAge": .int(18)])
```

### Relationships

```swift
let from = RecordID(table: "users", id: "john")
let to = RecordID(table: "posts", id: "post123")

// Create relationship using relate()
let edge: AuthoredEdge = try await db.relate(
    from: from,
    via: "authored",
    to: to,
    data: AuthoredData(publishedAt: Date())
)

// Or use insertRelation() for direct edge insertion
struct EdgeData: Codable {
    let `in`: String
    let out: String
    let createdAt: Date
}

let relationship: EdgeData = try await db.insertRelation(
    "authored",
    data: EdgeData(in: "users:john", out: "posts:123", createdAt: Date())
)
```

### Live Queries

Subscribe to real-time database changes:

```swift
// Create a live query
let (queryId, stream) = try await db.live("users")

for await notification in stream {
    switch notification.action {
    case .create:
        print("New user:", notification.result)
    case .update:
        print("Updated user:", notification.result)
    case .delete:
        print("Deleted user:", notification.result)
    case .close:
        break
    }
}

// Subscribe to an existing live query from another context
let additionalStream = try await db.subscribeLive(queryId)

// Kill the live query when done
try await db.kill(queryId)
```

### Backup and Restore

Export and import database contents (HTTP transport only):

```swift
// Export all data to SurrealQL
let backup = try await db.export()
try backup.write(to: URL(fileURLWithPath: "backup.surql"))

// Export specific tables
let userBackup = try await db.export(options: ExportOptions(
    tables: ["users", "profiles"],
    functions: false
))

// Import from SurrealQL file
let sql = try String(contentsOf: URL(fileURLWithPath: "backup.surql"))
try await db.import(sql)
```

## Transport Options

### WebSocket (Recommended)

WebSocket transport provides full functionality including live queries:

```swift
let db = try SurrealDB(url: "ws://localhost:8000/rpc", transportType: .websocket)
```

**Supported operations**: All operations including live queries, variables, and subscriptions.

### HTTP

HTTP transport is simpler but has some limitations:

```swift
let db = try SurrealDB(url: "http://localhost:8000", transportType: .http)
```

**Supported operations**: CRUD, queries, authentication, export/import.
**Limitations**: No live queries, no variables (`let`/`unset`), no subscriptions.

## Error Handling

All operations can throw `SurrealError`:

```swift
do {
    try await db.select("users")
} catch let error as SurrealError {
    switch error {
    case .connectionError(let message):
        print("Connection failed:", message)
    case .rpcError(let code, let message, _):
        print("RPC error \(code):", message)
    case .authenticationError(let message):
        print("Authentication failed:", message)
    default:
        print("Error:", error)
    }
}
```

## Testing

Run the unit tests:

```bash
swift test
```

Run integration tests (requires running SurrealDB instance).
These are intentionally local-only and skipped in default CI runs:

```bash
# Start SurrealDB
surreal start --user root --pass root memory

# Run integration tests
SURREALDB_TEST=1 swift test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built for [SurrealDB](https://surrealdb.com)
- Inspired by the official [JavaScript SDK](https://github.com/surrealdb/surrealdb.js)

## Resources

- [SurrealDB Documentation](https://surrealdb.com/docs)
- [SurrealDB Discord](https://discord.gg/surrealdb)
- [SurrealQL Reference](https://surrealdb.com/docs/surrealql)
