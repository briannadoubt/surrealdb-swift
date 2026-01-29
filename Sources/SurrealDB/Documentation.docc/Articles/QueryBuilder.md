# Query Builder

Build type-safe SurrealQL queries with a fluent API.

## Overview

The query builder provides an ergonomic, type-safe way to construct SurrealQL queries without writing raw SQL strings. It supports all major query operations including SELECT, CREATE, UPDATE, DELETE, and RELATE.

## Basic SELECT Queries

### Selecting All Records

```swift
let users: [User] = try await db
    .query()
    .select()
    .from("users")
    .fetch()
```

### Selecting Specific Fields

```swift
let users: [User] = try await db
    .query()
    .select("name", "email", "createdAt")
    .from("users")
    .fetch()
```

### Filtering with WHERE

```swift
let adults: [User] = try await db
    .query()
    .select()
    .from("users")
    .where("age >= 18")
    .fetch()
```

## Sorting and Pagination

### ORDER BY

```swift
let users: [User] = try await db
    .query()
    .select()
    .from("users")
    .orderBy("name", ascending: true)
    .fetch()
```

### LIMIT and START

```swift
// Get 10 users, skip first 20
let users: [User] = try await db
    .query()
    .select()
    .from("users")
    .start(20)
    .limit(10)
    .fetch()
```

## Creating Records

### Simple Create

```swift
try await db
    .query()
    .create("users")
    .set("name", to: .string("John"))
    .set("age", to: .int(30))
    .execute()
```

### Create with Content

```swift
let user = User(name: "Jane", email: "jane@example.com", age: 28)

try await db
    .query()
    .create("users")
    .content(user)
    .execute()
```

## Updating Records

### Update Specific Fields

```swift
try await db
    .query()
    .update("users:john")
    .set("age", to: .int(31))
    .set("lastLogin", to: .string(Date().ISO8601Format()))
    .execute()
```

### Update with Content

```swift
let updates = UserUpdates(age: 31, city: "San Francisco")

try await db
    .query()
    .update("users:john")
    .content(updates)
    .execute()
```

### Conditional Updates

```swift
try await db
    .query()
    .update("users")
    .set("verified", to: .bool(true))
    .where("email IS NOT NONE")
    .execute()
```

## Deleting Records

### Delete Specific Record

```swift
try await db
    .query()
    .delete("users:john")
    .execute()
```

### Conditional Delete

```swift
try await db
    .query()
    .delete("users")
    .where("lastLogin < time::now() - 1y")
    .execute()
```

## Relationships with RELATE

```swift
let from = RecordID(table: "users", id: "john")
let to = RecordID(table: "posts", id: "post123")

try await db
    .query()
    .relate(from, to: to, via: "authored")
    .set("publishedAt", to: .string(Date().ISO8601Format()))
    .execute()
```

## Grouping

```swift
try await db
    .query()
    .select("country", "count()")
    .from("users")
    .groupBy("country")
    .execute()
```

## Fetching Results

### Fetch Multiple Results

```swift
let users: [User] = try await db
    .query()
    .select()
    .from("users")
    .fetch()
```

### Fetch Single Result

```swift
let user: User? = try await db
    .query()
    .select()
    .from("users:john")
    .fetchOne()
```

### Get Raw Results

```swift
let results: [SurrealValue] = try await db
    .query()
    .select()
    .from("users")
    .execute()
```

## Complex Queries

### Combining Filters

```swift
let users: [User] = try await db
    .query()
    .select()
    .from("users")
    .where("age >= 18 AND verified = true")
    .orderBy("createdAt", ascending: false)
    .limit(20)
    .fetch()
```

### Parameterized Queries

For complex filtering, use variable binding:

```swift
let minAge = 18
let results = try await db
    .query()
    .select()
    .from("users")
    .where("age >= $minAge")
    .execute()
```

Variables are automatically bound and escaped to prevent injection.

## When to Use Query Builder vs. Raw Queries

**Use Query Builder for:**
- Simple CRUD operations
- Standard SELECT/WHERE/ORDER BY queries
- Programmatically constructed queries
- Type-safe results

**Use Raw Queries for:**
- Complex SurrealQL features
- Graph traversals
- Subqueries and UNION
- Advanced SurrealDB features

Example of a complex query better suited for raw SQL:

```swift
let results = try await db.query("""
    SELECT
        ->authored->posts[WHERE published = true] AS posts,
        ->follows->users AS following
    FROM users:john
""")
```

## Error Handling

```swift
do {
    let users: [User] = try await db
        .query()
        .select()
        .from("users")
        .fetch()
} catch let error as SurrealError {
    print("Query failed:", error)
}
```

## Best Practices

1. **Use specific field selection** - Don't select all fields if you only need a few

2. **Add pagination** - Always use LIMIT for queries that might return many records

3. **Type your results** - Use typed fetch() over raw execute() when possible

4. **Validate inputs** - Ensure user inputs are safe before using in WHERE clauses

5. **Prefer builder for simple queries** - Use raw queries for complex operations

## Complete Example

```swift
import SurrealDB

struct UserQuery {
    let db: SurrealDB

    func findActiveUsers(country: String, page: Int, pageSize: Int) async throws -> [User] {
        try await db
            .query()
            .select("name", "email", "lastLogin")
            .from("users")
            .where("country = '\(country)' AND active = true")
            .orderBy("lastLogin", ascending: false)
            .start(page * pageSize)
            .limit(pageSize)
            .fetch()
    }

    func createUser(name: String, email: String) async throws -> User {
        let newUser = NewUser(name: name, email: email, createdAt: Date())

        let results: [User] = try await db
            .query()
            .create("users")
            .content(newUser)
            .fetch()

        guard let user = results.first else {
            throw QueryError.noResult
        }

        return user
    }

    func updateUserAge(userId: String, age: Int) async throws {
        try await db
            .query()
            .update("users:\(userId)")
            .set("age", to: .int(age))
            .execute()
    }
}

enum QueryError: Error {
    case noResult
}
```
