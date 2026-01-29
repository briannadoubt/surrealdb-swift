# Quick Start Guide

Get started with SurrealDB Swift in 5 minutes.

## Installation

Add SurrealDB Swift to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/surrealdb-swift", from: "1.0.0")
]
```

## Basic Usage

### 1. Connect to Database

```swift
import SurrealDB

// Create database instance
let db = SurrealDB(url: "ws://localhost:8000/rpc")

// Connect
try await db.connect()

// Authenticate
try await db.signin(username: "root", password: "root")

// Select namespace and database
try await db.use(namespace: "test", database: "test")
```

### 2. Define Your Models

```swift
struct User: SurrealModel {
    var id: RecordID?
    var name: String
    var email: String
    var age: Int

    static var tableName: String { "users" }
}
```

### 3. CRUD Operations

```swift
// Create
var user = User(id: nil, name: "John Doe", email: "john@example.com", age: 30)
user = try await db.create(user)
print("Created user: \(user.id!)")

// Read
let users: [User] = try await db.select("users")
print("Found \(users.count) users")

// Read specific
if let user: User = try await db.select(user.id!) {
    print("User: \(user.name)")
}

// Update
user.age = 31
user = try await db.update(user)

// Delete
try await db.delete(user)
```

## Advanced Features

### Type-Safe Queries

Use KeyPaths instead of strings for compile-time safety:

```swift
let adults = try await db.query(User.self)
    .where(\User.age >= 18)
    .where(\User.email != "")
    .orderBy(\User.name)
    .limit(10)
    .fetch()
```

### Relationships

Define relationships between models:

```swift
struct Post: SurrealModel {
    var id: RecordID?
    var title: String
    var content: String
}

struct Authored: EdgeModel {
    typealias From = User
    typealias To = Post
    var publishedAt: Date
}

// Create relationship
let post = Post(id: nil, title: "Hello", content: "World")
let savedPost = try await db.create(post)

try await user.relate(
    to: savedPost,
    via: Authored(publishedAt: Date()),
    using: db
)

// Load relationships
let posts = try await user.loadBatch(\.posts, using: db)
```

### Batch Loading (N+1 Solution)

Load relationships for multiple records efficiently:

```swift
let users: [User] = try await db.query(User.self).fetch()

// Load ALL posts for ALL users in ONE query (90%+ faster)
let postsMap = try await users.loadAllRelationships(\.posts, using: db)

for user in users {
    let userPosts = postsMap[user.id!.toString()] ?? []
    print("\(user.name): \(userPosts.count) posts")
}
```

### Property Wrappers

Use property wrappers for enhanced functionality:

```swift
struct User: SurrealModel {
    @ID(strategy: .uuid) var id: RecordID?

    @Index(type: .unique)
    var email: String

    var name: String

    @Computed<Int>(count: "posts")
    var postCount: Int?

    @Relation(edge: Authored.self, direction: .out)
    var posts: [Post]
}
```

### Graph Queries

Traverse relationships with the fluent graph API:

```swift
// Multi-hop traversal: User -> Posts -> Comments
let comments = try await db.graphQuery(User.self)
    .from(userID)
    .traverse(\.posts, depth: 1)
    .traverse(\.comments, depth: 2)
    .limit(100)
    .fetch()

// Count relationships
let postCount = try await user.relatedCount(\.posts, using: db)
```

## Next Steps

- **[Advanced Features](ADVANCED_FEATURES.md)** - Complete guide to property wrappers, batch loading, and graph queries
- **[API Reference](API_REFERENCE.md)** - Full API documentation
- **[Examples](../Examples/)** - Working example projects

## Common Patterns

### Pagination

```swift
func fetchPage<T: SurrealModel>(_ type: T.Type, page: Int, size: Int = 20) async throws -> [T] {
    try await db.query(type)
        .orderBy(\T.id)
        .limit(size)
        .offset(page * size)
        .fetch()
}
```

### Search

```swift
func searchUsers(query: String) async throws -> [User] {
    try await db.query(User.self)
        .where(\User.name contains query)
        .orderBy(\User.name)
        .fetch()
}
```

### Aggregation

```swift
struct UserStats: Codable {
    @Computed<Int>(count: "*")
    var totalUsers: Int?

    @Computed<Double>(avg: "age")
    var averageAge: Double?
}

let stats: [UserStats] = try await db.query("""
    SELECT
        count(*) as totalUsers,
        avg(age) as averageAge
    FROM users
""")
```

## Testing

The package includes comprehensive test coverage:

```bash
# Unit tests
swift test

# With integration tests (requires SurrealDB running)
SURREALDB_TEST=1 swift test
```

## Platform Support

- macOS 15+
- iOS 18+
- tvOS 18+
- watchOS 11+
- visionOS 2+

## Performance Tips

1. **Use batch loading** for relationships (90%+ faster)
2. **Count without loading** when you only need totals
3. **Select specific fields** instead of SELECT *
4. **Limit graph depth** to prevent infinite traversals
5. **Use indexes** on frequently queried fields

## Help & Support

- **Documentation:** [Full Documentation](ADVANCED_FEATURES.md)
- **Issues:** [GitHub Issues](https://github.com/yourusername/surrealdb-swift/issues)
- **Examples:** [Example Projects](../Examples/)

## License

MIT License - see LICENSE file for details
