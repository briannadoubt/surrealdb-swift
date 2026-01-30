# Getting Started

Learn how to install and use the SurrealDB Swift client.

## Installation

### Swift Package Manager

Add SurrealDB to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/surrealdb-swift.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SurrealDB"]
)
```

## Basic Usage

### Connecting to the Database

```swift
import SurrealDB

// Create a client with WebSocket transport
let db = try SurrealDB(url: "ws://localhost:8000/rpc", transportType: .websocket)

// Or use HTTP transport
let db = try SurrealDB(url: "http://localhost:8000", transportType: .http)

// Connect to the server
try await db.connect()
```

### Authentication

```swift
// Root user authentication
try await db.signin(.root(
    RootAuth(username: "root", password: "root")
))

// Select namespace and database
try await db.use(namespace: "test", database: "test")
```

### Creating Records

```swift
struct User: Codable {
    let name: String
    let email: String
    let age: Int
}

let newUser = User(name: "John Doe", email: "john@example.com", age: 30)
let created: User = try await db.create("users", data: newUser)
```

### Querying Records

```swift
// Select all users
let users: [User] = try await db.select("users")

// Select a specific user
let user: User = try await db.select("users:john")
```

### Updating Records

```swift
let updates = ["age": 31]
let updated: User = try await db.merge("users:john", data: updates)
```

### Deleting Records

```swift
try await db.delete("users:john")
```

### Custom Queries

```swift
let results = try await db.query(
    "SELECT * FROM users WHERE age > $minAge",
    variables: ["minAge": .int(25)]
)
```

## Using the Query Builder

The query builder provides a fluent API for constructing queries:

```swift
let adults: [User] = try await db
    .query()
    .select("name", "email", "age")
    .from("users")
    .where("age >= 18")
    .orderBy("name")
    .limit(10)
    .fetch()
```

## Live Queries

Subscribe to real-time changes:

```swift
let (queryId, stream) = try await db.live("users")

Task {
    for await notification in stream {
        switch notification.action {
        case .create:
            print("New user created:", notification.result)
        case .update:
            print("User updated:", notification.result)
        case .delete:
            print("User deleted:", notification.result)
        case .close:
            print("Live query closed")
        }
    }
}

// Later, stop the live query
try await db.kill(queryId)
```

## Error Handling

All operations can throw `SurrealError`:

```swift
do {
    let users: [User] = try await db.select("users")
} catch let error as SurrealError {
    switch error {
    case .connectionError(let message):
        print("Connection failed:", message)
    case .rpcError(let code, let message, _):
        print("RPC error \(code):", message)
    case .authenticationError(let message):
        print("Auth failed:", message)
    default:
        print("Error:", error)
    }
}
```

## Cleanup

Always disconnect when done:

```swift
try await db.disconnect()
```

## Next Steps

- Learn about <doc:Authentication> strategies
- Explore <doc:LiveQueries> for real-time features
- Master the <doc:QueryBuilder> for complex queries
