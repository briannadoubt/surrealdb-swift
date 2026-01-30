# Advanced Type Safety for SurrealDB Swift

This document explores making the SurrealDB Swift client more type-aware and graph-native.

## Table of Contents

1. [Type-Safe Query Syntax](#type-safe-query-syntax)
2. [Graph Relationships](#graph-relationships)
3. [Property Wrappers](#property-wrappers)
4. [Result Builders](#result-builders)
5. [Trebuchet Integration](#trebuchet-integration)

---

## 1. Type-Safe Query Syntax

### Current Approach (String-Based)

```swift
let adults: [User] = try await db
    .query()
    .select("name", "email")
    .from("users")
    .where("age >= 18")  // ⚠️ No compile-time safety
    .fetch()
```

**Problems:**
- No compile-time validation
- Typos aren't caught
- Field names can drift from model
- No autocomplete

### Solution A: KeyPath-Based Queries

```swift
// Using Swift KeyPaths for type safety
let adults: [User] = try await db
    .query()
    .select(\User.name, \User.email)
    .from(User.self)
    .where(\User.age >= 18)  // ✅ Compile-time safe!
    .fetch()
```

**Implementation:**

```swift
// Extend QueryBuilder with KeyPath support
extension QueryBuilder {
    func select<T, V>(_ keyPaths: KeyPath<T, V>...) -> QueryBuilder {
        let fieldNames = keyPaths.map { keyPath in
            // Extract property name from KeyPath
            String(describing: keyPath).components(separatedBy: ".").last!
        }
        return select(fieldNames)
    }

    func where<T, V: Comparable>(
        _ keyPath: KeyPath<T, V>,
        _ operation: PredicateOperation,
        _ value: V
    ) -> QueryBuilder {
        let fieldName = extractFieldName(from: keyPath)
        return where("\(fieldName) \(operation.rawValue) \(value)")
    }
}

enum PredicateOperation: String {
    case equals = "="
    case notEquals = "!="
    case greaterThan = ">"
    case lessThan = "<"
    case greaterThanOrEqual = ">="
    case lessThanOrEqual = "<="
}
```

### Solution B: Result Builder DSL

```swift
// Use Swift's result builder for query construction
let adults = try await db.query(User.self) {
    Select {
        \User.name
        \User.email
    }
    Where {
        \User.age >= 18
        \User.verified == true
    }
    OrderBy(\User.name, .ascending)
    Limit(10)
}
```

**Implementation:**

```swift
@resultBuilder
struct QueryDSL {
    static func buildBlock(_ components: QueryComponent...) -> [QueryComponent] {
        components
    }
}

protocol QueryComponent {
    func toSurrealQL() -> String
}

struct Select: QueryComponent {
    let fields: [PartialKeyPath<Any>]

    init(@ArrayBuilder<PartialKeyPath<Any>> _ fields: () -> [PartialKeyPath<Any>]) {
        self.fields = fields()
    }

    func toSurrealQL() -> String {
        let fieldNames = fields.map { extractFieldName(from: $0) }
        return "SELECT \(fieldNames.joined(separator: ", "))"
    }
}

struct Where: QueryComponent {
    let predicates: [Predicate]

    init(@ArrayBuilder<Predicate> _ predicates: () -> [Predicate]) {
        self.predicates = predicates()
    }

    func toSurrealQL() -> String {
        let conditions = predicates.map { $0.toSurrealQL() }
        return "WHERE \(conditions.joined(separator: " AND "))"
    }
}
```

---

## 2. Graph Relationships

### Current Approach

```swift
let from = RecordID(table: "users", id: "john")
let to = RecordID(table: "posts", id: "post123")

let edge: Authored = try await db.relate(
    from: from,
    via: "authored",
    to: to,
    data: Authored(publishedAt: Date())
)
```

### Type-Safe Relationships

```swift
// Define models with relationships
struct User: SurrealModel {
    @ID var id: RecordID?
    var name: String
    var email: String

    // Relationships
    @Relation(edge: Authored.self)
    var posts: [Post]

    @Relation(edge: Follows.self, direction: .out)
    var following: [User]

    @Relation(edge: Follows.self, direction: .in)
    var followers: [User]
}

struct Post: SurrealModel {
    @ID var id: RecordID?
    var title: String
    var content: String

    @Relation(edge: Authored.self, direction: .in)
    var author: User
}

struct Authored: EdgeModel {
    typealias From = User
    typealias To = Post

    var publishedAt: Date
    var featured: Bool
}

struct Follows: EdgeModel {
    typealias From = User
    typealias To = User

    var since: Date
}
```

### Usage

```swift
// Create relationship
try await user.relate(to: post, via: Authored(
    publishedAt: Date(),
    featured: true
))

// Query with relationships
let user: User = try await db.select("users:john")
    .fetch(including: \.posts)  // ✅ Type-safe relationship loading

// Traverse graph
let posts = user.posts  // Automatically loaded
let author = posts[0].author  // ✅ Type-safe back-reference
```

---

## 3. Property Wrappers

### Record ID Management

```swift
@propertyWrapper
struct ID: Codable {
    var wrappedValue: RecordID?

    init(wrappedValue: RecordID? = nil) {
        self.wrappedValue = wrappedValue
    }
}

// Usage
struct User: Codable {
    @ID var id: RecordID?
    var name: String
}
```

### Relationships

```swift
@propertyWrapper
struct Relation<T: SurrealModel, Edge: EdgeModel>: Codable {
    enum Direction {
        case `in`, out, both
    }

    private var _value: [T]?
    var wrappedValue: [T] {
        get { _value ?? [] }
        set { _value = newValue }
    }

    let edge: Edge.Type
    let direction: Direction

    init(edge: Edge.Type, direction: Direction = .out) {
        self.edge = edge
        self.direction = direction
        self._value = nil
    }
}

// Usage
struct User: SurrealModel {
    @ID var id: RecordID?

    @Relation(edge: Authored.self)
    var posts: [Post]

    @Relation(edge: Follows.self, direction: .out)
    var following: [User]
}
```

### Computed Fields

```swift
@propertyWrapper
struct Computed<T: Codable> {
    let expression: String
    var wrappedValue: T?

    init(_ expression: String) {
        self.expression = expression
    }
}

// Usage
struct User: SurrealModel {
    @ID var id: RecordID?
    var firstName: String
    var lastName: String

    @Computed("firstName + ' ' + lastName")
    var fullName: String?

    @Computed("count(->authored->post)")
    var postCount: Int?
}
```

---

## 4. Result Builders

### Query DSL

```swift
extension SurrealDB {
    func query<T: SurrealModel>(
        _ type: T.Type,
        @QueryDSL builder: () -> [QueryComponent]
    ) async throws -> [T] {
        let components = builder()
        let query = components.map { $0.toSurrealQL() }.joined(separator: " ")
        return try await self.query(query, variables: nil).first?.decode() ?? []
    }
}

// Usage
let users = try await db.query(User.self) {
    Select {
        \User.name
        \User.email
    }
    Where {
        \User.age >= 18
        \User.verified == true
    }
    OrderBy(\User.createdAt, .descending)
    Limit(10)
}
```

### Relationship Traversal Builder

```swift
@resultBuilder
struct GraphTraversal {
    static func buildBlock(_ components: TraversalStep...) -> [TraversalStep] {
        components
    }
}

struct TraversalStep {
    let relation: String
    let direction: Direction

    enum Direction {
        case out, `in`
    }
}

extension SurrealModel {
    func traverse(@GraphTraversal builder: () -> [TraversalStep]) async throws -> [Any] {
        // Build graph traversal query
        let steps = builder()
        let query = steps.map { step in
            switch step.direction {
            case .out: return "->\(step.relation)->"
            case .in: return "<-\(step.relation)<-"
            }
        }.joined()

        // Execute traversal
        return []  // Implementation
    }
}

// Usage
let related = try await user.traverse {
    TraversalStep(relation: "authored", direction: .out)  // -> posts
    TraversalStep(relation: "tagged", direction: .out)     // -> tags
}
```

---

## 5. Trebuchet Integration

### The Challenge

Trebuchet uses distributed actors with `@Trebuchet` macro. We need to ensure:
1. The SurrealDB client works in distributed contexts
2. No unnecessary interface duplication
3. Proper serialization across actor boundaries

### Solution: Protocol-Based Architecture

```swift
// Core protocol that both local and distributed implementations conform to
public protocol SurrealDBProtocol: Sendable {
    func connect() async throws
    func disconnect() async throws
    func select<T: Decodable>(_ target: String) async throws -> [T]
    func create<T: Encodable, R: Decodable>(_ target: String, data: T?) async throws -> R
    func query(_ sql: String, variables: [String: SurrealValue]?) async throws -> [SurrealValue]
    func live(_ table: String, diff: Bool) async throws -> (id: String, stream: AsyncStream<LiveQueryNotification>)
    // ... other methods
}

// Local actor implementation (current)
public actor SurrealDB: SurrealDBProtocol {
    // Existing implementation
}

// Distributed actor wrapper for Trebuchet
@Trebuchet
public distributed actor DistributedSurrealDB: SurrealDBProtocol {
    private let client: SurrealDB

    public init(url: String, transportType: TransportType = .websocket) async throws {
        self.client = try SurrealDB(url: url, transportType: transportType)
        try await client.connect()
    }

    public distributed func connect() async throws {
        try await client.connect()
    }

    public distributed func select<T: Decodable>(_ target: String) async throws -> [T] {
        try await client.select(target)
    }

    // Delegate all methods to local client
    // ...
}
```

### Shared Service Pattern

```swift
// Define a shared service protocol
public protocol DatabaseService: Sendable {
    associatedtype Client: SurrealDBProtocol
    var db: Client { get }
}

// Local implementation
public actor LocalDatabaseService: DatabaseService {
    public let db: SurrealDB

    public init(url: String) async throws {
        self.db = try SurrealDB(url: url)
        try await db.connect()
    }
}

// Distributed implementation
@Trebuchet
public distributed actor DistributedDatabaseService: DatabaseService {
    public let db: DistributedSurrealDB

    public init(url: String) async throws {
        self.db = try await DistributedSurrealDB(url: url)
    }
}

// Usage - same interface!
func fetchUsers<Service: DatabaseService>(from service: Service) async throws -> [User] {
    try await service.db.select("users")
}
```

### Alternative: Type Erasure

```swift
// Type-erased wrapper
public struct AnySurrealDB: SurrealDBProtocol {
    private let _connect: () async throws -> Void
    private let _select: (String) async throws -> [Any]
    // ... all methods as closures

    public init<T: SurrealDBProtocol>(_ concrete: T) {
        self._connect = { try await concrete.connect() }
        self._select = { try await concrete.select($0) }
        // ... wrap all methods
    }

    public func connect() async throws {
        try await _connect()
    }

    public func select<T: Decodable>(_ target: String) async throws -> [T] {
        try await _select(target) as! [T]
    }
}

// Usage
let localDB = try SurrealDB(url: "ws://localhost:8000/rpc")
let distributedDB = try await DistributedSurrealDB(url: "ws://remote:8000/rpc")

// Same interface!
let anyDB1 = AnySurrealDB(localDB)
let anyDB2 = AnySurrealDB(distributedDB)
```

---

## Complete Type-Safe Example

```swift
import SurrealDB
import Trebuchet

// 1. Define models with relationships
struct User: SurrealModel {
    @ID var id: RecordID?
    var name: String
    var email: String
    var age: Int

    @Relation(edge: Authored.self)
    var posts: [Post]

    @Relation(edge: Follows.self, direction: .out)
    var following: [User]

    @Computed("count(->authored->post)")
    var postCount: Int?
}

struct Post: SurrealModel {
    @ID var id: RecordID?
    var title: String
    var content: String

    @Relation(edge: Authored.self, direction: .in)
    var author: User

    @Relation(edge: Tagged.self)
    var tags: [Tag]
}

struct Tag: SurrealModel {
    @ID var id: RecordID?
    var name: String
}

// 2. Define edge models
struct Authored: EdgeModel {
    typealias From = User
    typealias To = Post
    var publishedAt: Date
}

struct Follows: EdgeModel {
    typealias From = User
    typealias To = User
    var since: Date
}

struct Tagged: EdgeModel {
    typealias From = Post
    typealias To = Tag
}

// 3. Use type-safe queries
let adults = try await db.query(User.self) {
    Select {
        \User.name
        \User.email
        \User.postCount
    }
    Where {
        \User.age >= 18
        \User.email.contains("@example.com")
    }
    OrderBy(\User.name, .ascending)
    Limit(10)
}

// 4. Create relationships
let user = User(name: "John", email: "john@example.com", age: 30)
let post = Post(title: "Hello", content: "World")

try await user.relate(to: post, via: Authored(publishedAt: Date()))

// 5. Load with relationships
let userWithPosts: User = try await db
    .select("users:john")
    .fetch(including: \.posts, \.following)

print("Posts by \(userWithPosts.name):")
for post in userWithPosts.posts {
    print("- \(post.title)")
}

// 6. Traverse graph
let recommendations = try await user.traverse {
    Step(\User.following)  // -> users they follow
    Step(\User.posts)      // -> posts by those users
    Step(\Post.tags)       // -> tags on those posts
}

// 7. Use with Trebuchet
@Trebuchet
distributed actor UserService {
    let db: DistributedSurrealDB

    init() async throws {
        self.db = try await DistributedSurrealDB(url: "ws://db:8000/rpc")
    }

    distributed func getRecommendations(for userId: String) async throws -> [Post] {
        // Same API as local!
        let user: User = try await db.select("users:\(userId)")
            .fetch(including: \.following)

        return try await db.query(Post.self) {
            Select { \Post.title, \Post.content }
            Where {
                \Post.author.id.in(user.following.map(\.id))
            }
            OrderBy(\Post.publishedAt, .descending)
            Limit(10)
        }
    }
}
```

---

## Implementation Roadmap

### Phase 1: Property Wrappers
- [ ] `@ID` for record IDs
- [ ] `@Relation` for relationships
- [ ] `@Computed` for computed fields
- [ ] `@Index` for indexing hints

### Phase 2: KeyPath Queries
- [ ] KeyPath-based select
- [ ] KeyPath-based where clauses
- [ ] KeyPath-based ordering
- [ ] Type extraction from KeyPaths

### Phase 3: Result Builders
- [ ] `@QueryDSL` result builder
- [ ] Query components (Select, Where, etc.)
- [ ] Type-safe predicates
- [ ] Graph traversal builder

### Phase 4: Graph Models
- [ ] `SurrealModel` protocol
- [ ] `EdgeModel` protocol
- [ ] Relationship loading
- [ ] Automatic joins

### Phase 5: Trebuchet Integration
- [ ] `SurrealDBProtocol` extraction
- [ ] `DistributedSurrealDB` actor
- [ ] Serialization helpers
- [ ] Documentation

---

## Benefits

✅ **Compile-time safety** - Catch errors before runtime
✅ **Autocomplete** - IDE helps with field names
✅ **Refactoring** - Rename fields safely
✅ **Graph-native** - First-class relationship support
✅ **Distributed-ready** - Works with Trebuchet
✅ **Clean API** - No string interpolation needed

## Trade-offs

⚠️ **Learning curve** - More complex API
⚠️ **Compilation time** - Result builders can be slow
⚠️ **Flexibility** - Some queries harder to express
⚠️ **Runtime overhead** - KeyPath reflection has cost

---

For discussion: Which features should we prioritize?
