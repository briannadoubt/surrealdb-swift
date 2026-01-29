# SurrealDB Swift API Reference

Complete API documentation for the SurrealDB Swift client.

## Table of Contents

1. [Initialization](#initialization)
2. [Connection Management](#connection-management)
3. [Authentication](#authentication)
4. [Database Selection](#database-selection)
5. [CRUD Operations](#crud-operations)
6. [Queries](#queries)
7. [Live Queries](#live-queries)
8. [Advanced Operations](#advanced-operations)
9. [Query Builder](#query-builder)
10. [Error Handling](#error-handling)

---

## Initialization

```swift
import SurrealDB

// WebSocket transport (recommended for full features)
let db = try SurrealDB(url: "ws://localhost:8000/rpc", transportType: .websocket)

// HTTP transport (simpler, but no live queries)
let db = try SurrealDB(url: "http://localhost:8000", transportType: .http)
```

---

## Connection Management

### Connect

```swift
try await db.connect()
```

### Disconnect

```swift
try await db.disconnect()
```

### Check Connection Status

```swift
let connected = await db.isConnected
if connected {
    print("Connected to SurrealDB")
}
```

### Ping Server

```swift
try await db.ping()
```

### Get Server Version

```swift
let version = try await db.version()
print("SurrealDB version: \(version)")
```

---

## Authentication

### Root Authentication

```swift
try await db.signin(.root(
    RootAuth(username: "root", password: "root")
))
```

### Namespace Authentication

```swift
try await db.signin(.namespace(
    NamespaceAuth(
        namespace: "myapp",
        username: "admin",
        password: "secret"
    )
))
```

### Database Authentication

```swift
try await db.signin(.database(
    DatabaseAuth(
        namespace: "myapp",
        database: "production",
        username: "dbuser",
        password: "secret"
    )
))
```

### Record Access (User) Authentication

```swift
// Sign in existing user
try await db.signin(.recordAccess(
    RecordAccessAuth(
        namespace: "myapp",
        database: "production",
        access: "user",
        variables: [
            "email": .string("user@example.com"),
            "pass": .string("password123")
        ]
    )
))
```

### Sign Up New User

```swift
let token = try await db.signup(
    RecordAccessAuth(
        namespace: "myapp",
        database: "production",
        access: "user",
        variables: [
            "email": .string("newuser@example.com"),
            "pass": .string("password123"),
            "name": .string("New User")
        ]
    )
)
```

### Authenticate with Token

```swift
try await db.authenticate(token: savedToken)
```

### Invalidate Session

```swift
try await db.invalidate()
```

### Get Session Info

```swift
let info = try await db.info()
print("Session info:", info)
```

---

## Database Selection

```swift
try await db.use(namespace: "myapp", database: "production")
```

---

## CRUD Operations

### Define Your Models

```swift
struct User: Codable {
    let id: String?
    let name: String
    let email: String
    let age: Int
    let createdAt: Date?
}

struct Post: Codable {
    let id: String?
    let title: String
    let content: String
    let authorId: String
}
```

### Create

```swift
// Create with auto-generated ID
let newUser = User(id: nil, name: "John", email: "john@example.com", age: 30, createdAt: nil)
let created: User = try await db.create("users", data: newUser)

// Create with specific ID
let user: User = try await db.create("users:john", data: newUser)

// Create without data (empty record)
let empty: User = try await db.create("users:temp")
```

### Select (Read)

```swift
// Select all records from a table
let allUsers: [User] = try await db.select("users")

// Select specific record
let users: [User] = try await db.select("users:john")
let user = users.first // Single record
```

### Insert

```swift
// Insert single record
let user = User(id: nil, name: "Jane", email: "jane@example.com", age: 28, createdAt: nil)
let inserted: [User] = try await db.insert("users", data: user)

// Insert multiple records
let users = [user1, user2, user3]
let inserted: [User] = try await db.insert("users", data: users)
```

### Update

```swift
// Update entire record
let updates = User(id: nil, name: "John Doe", email: "john@example.com", age: 31, createdAt: nil)
let updated: User = try await db.update("users:john", data: updates)

// Update all records in table
let updated: [User] = try await db.update("users", data: updates)
```

### Merge

```swift
// Merge specific fields
let changes = ["age": 32, "city": "San Francisco"]
let merged: User = try await db.merge("users:john", data: changes)
```

### Patch (JSON Patch)

```swift
// Apply JSON Patch operations
let patched: User = try await db.patch("users:john", patches: [
    .replace(path: "/age", value: .int(33)),
    .add(path: "/tags", value: .array([.string("admin"), .string("verified")])),
    .remove(path: "/temporaryField")
])
```

### Delete

```swift
// Delete specific record
try await db.delete("users:john")

// Delete all records in table
try await db.delete("users")
```

---

## Queries

### Raw SurrealQL

```swift
// Simple query
let results = try await db.query("SELECT * FROM users")

// Query with variables
let results = try await db.query(
    "SELECT * FROM users WHERE age > $minAge",
    variables: ["minAge": .int(18)]
)

// Multiple statements
let results = try await db.query("""
    CREATE users:alice SET name = 'Alice', age = 25;
    CREATE users:bob SET name = 'Bob', age = 30;
    SELECT * FROM users;
""")
```

### Variables (WebSocket only)

```swift
// Set variable
try await db.set(variable: "minAge", value: .int(18))

// Use in queries
let results = try await db.query("SELECT * FROM users WHERE age > $minAge")

// Unset variable
try await db.unset(variable: "minAge")
```

---

## Live Queries

> **Note:** Live queries require WebSocket transport

### Create Live Query

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
            break
        }
    }
}
```

### Live Query with Diff

```swift
// Get only changed fields instead of full records
let (queryId, stream) = try await db.live("users", diff: true)

for await notification in stream {
    print("Changed fields:", notification.result)
}
```

### Kill Live Query

```swift
try await db.kill(queryId)
```

### SwiftUI Integration Example

```swift
@MainActor
@Observable
class UserStore {
    private let db: SurrealDB
    private var queryId: String?
    var users: [User] = []

    func startLiveQuery() async throws {
        let (id, stream) = try await db.live("users")
        queryId = id

        Task {
            for await notification in stream {
                handleNotification(notification)
            }
        }
    }

    func stopLiveQuery() async throws {
        if let id = queryId {
            try await db.kill(id)
        }
    }

    private func handleNotification(_ notification: LiveQueryNotification) {
        // Update users array based on notification
        // ...
    }
}
```

---

## Advanced Operations

### Relationships (RELATE)

```swift
struct Authored: Codable {
    let publishedAt: Date
}

let from = RecordID(table: "users", id: "john")
let to = RecordID(table: "posts", id: "post123")

// Create relationship with data
let edge: Authored = try await db.relate(
    from: from,
    via: "authored",
    to: to,
    data: Authored(publishedAt: Date())
)

// Create relationship without data
let edge: Authored = try await db.relate(
    from: from,
    via: "follows",
    to: RecordID(table: "users", id: "jane")
)
```

### Custom Functions

```swift
// Call custom function
let result = try await db.run(
    function: "calculate_score",
    arguments: [.int(100), .int(50)]
)

// Call versioned function
let result = try await db.run(
    function: "calculate_score",
    version: "1.0.0",
    arguments: [.int(100)]
)
```

### GraphQL

```swift
let result = try await db.graphql("""
    query {
        users(where: { age: { gt: 18 } }) {
            id
            name
            email
        }
    }
""")
```

---

## Query Builder

The query builder provides a fluent, type-safe API for constructing queries.

### SELECT Queries

```swift
// Basic select
let users: [User] = try await db
    .query()
    .select("name", "email")
    .from("users")
    .fetch()

// With WHERE clause
let adults: [User] = try await db
    .query()
    .select()
    .from("users")
    .where("age >= 18")
    .fetch()

// With ORDER BY
let sorted: [User] = try await db
    .query()
    .select()
    .from("users")
    .orderBy("name", ascending: true)
    .fetch()

// With pagination
let page: [User] = try await db
    .query()
    .select()
    .from("users")
    .start(20)  // Skip first 20
    .limit(10)  // Get 10 records
    .fetch()

// Complex query
let result: [User] = try await db
    .query()
    .select("name", "email", "age")
    .from("users")
    .where("age >= 18 AND verified = true")
    .orderBy("createdAt", ascending: false)
    .limit(50)
    .fetch()
```

### CREATE Queries

```swift
// Create with SET
try await db
    .query()
    .create("users")
    .set("name", to: .string("Alice"))
    .set("age", to: .int(25))
    .execute()

// Create with CONTENT
let user = User(name: "Bob", email: "bob@example.com", age: 30)
try await db
    .query()
    .create("users")
    .content(user)
    .execute()
```

### UPDATE Queries

```swift
// Update with SET
try await db
    .query()
    .update("users:john")
    .set("age", to: .int(31))
    .set("lastLogin", to: .string(Date().ISO8601Format()))
    .execute()

// Update with WHERE
try await db
    .query()
    .update("users")
    .set("verified", to: .bool(true))
    .where("email IS NOT NULL")
    .execute()
```

### DELETE Queries

```swift
// Delete specific record
try await db
    .query()
    .delete("users:john")
    .execute()

// Delete with WHERE
try await db
    .query()
    .delete("users")
    .where("lastLogin < time::now() - 1y")
    .execute()
```

### RELATE Queries

```swift
let from = RecordID(table: "users", id: "john")
let to = RecordID(table: "posts", id: "post123")

try await db
    .query()
    .relate(from, to: to, via: "authored")
    .set("publishedAt", to: .string(Date().ISO8601Format()))
    .execute()
```

### Fetch Methods

```swift
// Fetch as array
let users: [User] = try await builder.fetch()

// Fetch single result
let user: User? = try await builder.fetchOne()

// Get raw SurrealValue results
let results: [SurrealValue] = try await builder.execute()
```

---

## Error Handling

### SurrealError Types

```swift
do {
    let users: [User] = try await db.select("users")
} catch let error as SurrealError {
    switch error {
    case .connectionError(let message):
        print("Connection failed:", message)

    case .rpcError(let code, let message, let data):
        print("RPC error \(code):", message)
        if let data = data {
            print("Additional data:", data)
        }

    case .authenticationError(let message):
        print("Auth failed:", message)

    case .timeout:
        print("Request timed out")

    case .invalidResponse(let message):
        print("Invalid response:", message)

    case .transportClosed:
        print("Connection closed")

    case .invalidRecordID(let message):
        print("Invalid record ID:", message)

    case .notConnected:
        print("Not connected to database")

    case .encodingError(let message):
        print("Encoding/decoding failed:", message)

    case .unsupportedOperation(let message):
        print("Operation not supported:", message)
    }
}
```

---

## Data Types

### SurrealValue

Dynamic value type for JSON-RPC protocol:

```swift
let value: SurrealValue = .object([
    "name": .string("John"),
    "age": .int(30),
    "active": .bool(true),
    "tags": .array([.string("admin"), .string("user")]),
    "settings": .object(["theme": .string("dark")])
])

// Subscript access
let name = value["name"]  // .string("John")
let firstTag = value["tags"]?[0]  // .string("admin")

// Convert to/from Codable types
let user = User(name: "John", email: "john@example.com", age: 30)
let surrealValue = try SurrealValue(from: user)
let decoded: User = try surrealValue.decode()
```

### RecordID

Type-safe record identifiers:

```swift
// Create from components
let id = RecordID(table: "users", id: "john")

// Parse from string
let id = try RecordID(parsing: "users:john")
let id = try RecordID(parsing: "users:⟨8c5ccf89-6c3c-4d11-8d7f-9ed5a3b95f6e⟩")

// Convert to string
let string = id.toString()  // "users:john"

// Use in queries
let users: [User] = try await db.select(id.toString())
```

---

## Complete Example

```swift
import SurrealDB

@main
struct MyApp {
    static func main() async throws {
        // 1. Connect
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()

        // 2. Authenticate
        try await db.signin(.root(
            RootAuth(username: "root", password: "root")
        ))
        try await db.use(namespace: "myapp", database: "production")

        // 3. Define model
        struct Todo: Codable {
            let id: String?
            let title: String
            let completed: Bool
        }

        // 4. Create records
        let todo: Todo = try await db.create("todos", data: Todo(
            id: nil,
            title: "Learn SurrealDB",
            completed: false
        ))

        // 5. Query with builder
        let todos: [Todo] = try await db
            .query()
            .select()
            .from("todos")
            .where("completed = false")
            .orderBy("title")
            .fetch()

        print("Pending todos:", todos)

        // 6. Live query
        let (queryId, stream) = try await db.live("todos")

        Task {
            for await notification in stream {
                print("Todo change:", notification.action, notification.result)
            }
        }

        // 7. Update
        let updated: Todo = try await db.merge("todos:\(todo.id!)", data: [
            "completed": true
        ])

        // 8. Clean up
        try await db.kill(queryId)
        try await db.disconnect()
    }
}
```

---

## API Summary

| Category | Methods |
|----------|---------|
| **Connection** | `connect()`, `disconnect()`, `isConnected`, `ping()`, `version()` |
| **Auth** | `signin()`, `signup()`, `authenticate()`, `invalidate()`, `info()` |
| **Database** | `use(namespace:database:)` |
| **Variables** | `set(variable:value:)`, `unset(variable:)` |
| **CRUD** | `create()`, `select()`, `insert()`, `update()`, `merge()`, `patch()`, `delete()` |
| **Queries** | `query(_:variables:)` |
| **Live** | `live(_:diff:)`, `kill(_:)` |
| **Advanced** | `relate()`, `run()`, `graphql()` |
| **Builder** | `query()` → fluent API |

---

For more details, see the [DocC documentation](./Sources/SurrealDB/Documentation.docc/).
