# SurrealDB Swift

A native Swift client for [SurrealDB](https://surrealdb.com), the ultimate multi-model database.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS%20|%20Linux-blue.svg)](https://swift.org)

## Features

- ✅ **WebSocket & HTTP transports** - Choose the right transport for your needs
- ✅ **Type-safe operations** - Leverage Swift's Codable for automatic encoding/decoding
- ✅ **Real-time live queries** - Subscribe to database changes in real-time
- ✅ **Fluent query builder** - Build SurrealQL queries with a type-safe API
- ✅ **Full SurrealQL support** - Execute any SurrealQL query directly
- ✅ **Swift 6 concurrency** - Built with modern Swift concurrency from the ground up
- ✅ **Cross-platform** - Supports all Apple platforms and Linux

## Requirements

- Swift 6.0+
- macOS 15.0+ / iOS 18.0+ / tvOS 18.0+ / watchOS 11.0+ / visionOS 2.0+
- SurrealDB 2.0+

## Installation

### Swift Package Manager

Add SurrealDB to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/surrealdb-swift.git", from: "1.0.0")
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

// Use the query builder
let adults: [User] = try await db
    .query()
    .select("name", "email")
    .from("users")
    .where("age >= 18")
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

## Documentation

Full documentation is available in the package:

```bash
swift package generate-documentation
```

Or browse the docs online at [link to your docs].

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

let edge: AuthoredEdge = try await db.relate(
    from: from,
    via: "authored",
    to: to,
    data: AuthoredData(publishedAt: Date())
)
```

## Transport Options

### WebSocket (Recommended)

WebSocket transport provides full functionality including live queries:

```swift
let db = try SurrealDB(url: "ws://localhost:8000/rpc", transportType: .websocket)
```

### HTTP

HTTP transport is simpler but doesn't support live queries or variables:

```swift
let db = try SurrealDB(url: "http://localhost:8000", transportType: .http)
```

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

Run integration tests (requires running SurrealDB instance):

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
