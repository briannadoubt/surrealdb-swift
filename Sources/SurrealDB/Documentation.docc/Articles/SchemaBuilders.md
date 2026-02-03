# Schema Builders

Build database schemas programmatically with fluent, type-safe APIs.

## Overview

The schema builder API provides a fluent interface for defining database schemas programmatically. It offers fine-grained control over tables, fields, and indexes with full type safety and copy-on-write immutability.

This API complements the ``@Surreal`` macro by providing explicit control when you need to:
- Define complex validation rules
- Create computed fields
- Build schemas dynamically
- Manage schema migrations
- Execute schema operations conditionally

## Accessing the Schema API

All schema operations are accessed through the ``SchemaBuilder``, which is available on your database client:

```swift
let db = try SurrealDB(url: "ws://localhost:8000/rpc")
try await db.connect()
try await db.use(namespace: "test", database: "test")

// Access the schema builder
let schema = db.schema
```

## Table Definitions

Use ``TableDefinitionBuilder`` to define tables with various configurations.

### Basic Table

Define a simple schemaless table:

```swift
try await db.schema
    .defineTable("users")
    .execute()
```

### Schemafull Table

Enforce strict schema validation:

```swift
try await db.schema
    .defineTable("users")
    .schemafull()
    .execute()
```

### Relation Table

Define a relation table connecting two tables:

```swift
try await db.schema
    .defineTable("follows")
    .relation(from: "users", to: "users")
    .execute()
```

### Conditional Definition

Use `ifNotExists()` to avoid errors if the table already exists:

```swift
try await db.schema
    .defineTable("users")
    .schemafull()
    .ifNotExists()
    .execute()
```

### Removing Tables

Remove a table definition:

```swift
try await db.schema
    .defineTable("old_users")
    .drop()
    .execute()

// Or use the shorthand
try await db.schema.removeTable("old_users")
```

## Field Definitions

Use ``FieldDefinitionBuilder`` to define fields with types, defaults, and validation.

### Basic Field

Define a field with a specific type:

```swift
try await db.schema
    .defineField("email", on: "users")
    .type(.string)
    .execute()
```

### Field with Default Value

Set a default value using SurrealQL:

```swift
try await db.schema
    .defineField("createdAt", on: "users")
    .type(.datetime)
    .default("time::now()")
    .execute()
```

### Field with Validation

Add assertions to validate field values:

```swift
try await db.schema
    .defineField("age", on: "users")
    .type(.int)
    .assert("$value >= 0 AND $value <= 150")
    .execute()
```

### Computed Field

Define fields calculated by the database:

```swift
try await db.schema
    .defineField("fullName", on: "users")
    .type(.string)
    .value("string::concat($this.firstName, ' ', $this.lastName)")
    .execute()
```

### Optional Field

Define nullable fields using `option<T>`:

```swift
try await db.schema
    .defineField("bio", on: "users")
    .type(.option(of: .string))
    .execute()
```

### Array Field

Define array fields with element types:

```swift
try await db.schema
    .defineField("tags", on: "posts")
    .type(.array(of: .string))
    .execute()
```

### Record Reference

Reference records from other tables:

```swift
try await db.schema
    .defineField("author", on: "posts")
    .type(.record(table: "users"))
    .execute()
```

### Flexible Object Field

Allow nested fields within an object:

```swift
try await db.schema
    .defineField("metadata", on: "users")
    .type(.object)
    .flexible()
    .execute()
```

### Removing Fields

Remove a field definition:

```swift
try await db.schema.removeField("oldColumn", from: "users")
```

## Index Definitions

Use ``IndexDefinitionBuilder`` to define indexes for query optimization.

### Standard Index

Create a standard index on one or more fields:

```swift
try await db.schema
    .defineIndex("idx_email", on: "users")
    .fields("email")
    .execute()
```

### Unique Index

Enforce uniqueness constraints:

```swift
try await db.schema
    .defineIndex("unique_email", on: "users")
    .fields("email")
    .unique()
    .execute()
```

### Multi-Field Index

Index multiple fields together:

```swift
try await db.schema
    .defineIndex("idx_name", on: "users")
    .fields("firstName", "lastName")
    .execute()
```

### Full-Text Index

Create a full-text search index:

```swift
try await db.schema
    .defineIndex("ft_content", on: "posts")
    .fields("content")
    .fulltext(analyzer: "ascii")
    .execute()
```

### Search Index

Create a BM25-based search index:

```swift
try await db.schema
    .defineIndex("search_title", on: "posts")
    .fields("title")
    .search(analyzer: "ascii")
    .execute()
```

### Conditional Index

Use `ifNotExists()` to avoid errors:

```swift
try await db.schema
    .defineIndex("idx_email", on: "users")
    .fields("email")
    .ifNotExists()
    .execute()
```

### Removing Indexes

Remove an index definition:

```swift
try await db.schema.removeIndex("old_idx", from: "users")
```

## Type System

The schema builder supports all SurrealDB types through the ``FieldType`` enum.

### Primitive Types

```swift
.any        // any
.string     // string
.int        // int
.float      // float
.decimal    // decimal
.bool       // bool
.datetime   // datetime
.duration   // duration
.uuid       // uuid
.bytes      // bytes
.null       // null
.object     // object
.number     // number
```

### Composite Types

```swift
.array(of: .string)              // array<string>
.set(of: .int)                   // set<int>
.option(of: .string)             // option<string>
.record(table: "users")          // record<users>
.record(table: nil)              // record
.geometry(subtype: .point)       // geometry<point>
.geometry(subtype: nil)          // geometry
```

### Nested Types

Types can be nested for complex structures:

```swift
.array(of: .option(of: .string))        // array<option<string>>
.option(of: .array(of: .int))           // option<array<int>>
.array(of: .record(table: "users"))     // array<record<users>>
```

## Method Chaining and Immutability

All builders use copy-on-write for immutability, allowing safe method chaining:

```swift
let baseTable = db.schema.defineTable("users")
let schemafullTable = baseTable.schemafull()  // Returns new instance
let withExists = schemafullTable.ifNotExists()  // Returns new instance

// baseTable remains unchanged
// Each method returns a new builder instance
```

This pattern enables:
- **Safe reuse** of builder configurations
- **Thread safety** with `Sendable` conformance
- **Flexible composition** of schema definitions

## Schema Introspection

Retrieve information about existing schemas:

### Database Info

Get information about all tables in the database:

```swift
let dbInfo = try await db.schema.info()
print(dbInfo)
```

### Table Info

Get detailed information about a specific table:

```swift
let tableInfo = try await db.schema.infoForTable("users")
print(tableInfo)
```

## Validation

All schema operations validate identifiers to ensure they:
- Are not empty
- Start with a letter or underscore
- Contain only letters, numbers, and underscores
- Are not SurrealDB reserved keywords

Field names support dot notation for nested fields (e.g., `metadata.createdBy`).

Invalid identifiers throw ``SurrealError/validationError(_:)``.

## Previewing SQL

Use `toSurrealQL()` to preview the generated SurrealQL before execution:

```swift
let builder = db.schema
    .defineTable("users")
    .schemafull()
    .ifNotExists()

let sql = try builder.toSurrealQL()
print(sql)
// "DEFINE TABLE IF NOT EXISTS users SCHEMAFULL"
```

This is useful for:
- Debugging schema definitions
- Generating migration scripts
- Understanding the builder output
- Testing schema logic

## Complete Example

Here's a comprehensive example defining a blog schema:

```swift
import SurrealDB

actor BlogSchema {
    let db: SurrealDB

    init(db: SurrealDB) {
        self.db = db
    }

    func setup() async throws {
        // Define users table
        try await db.schema
            .defineTable("users")
            .schemafull()
            .ifNotExists()
            .execute()

        // Define user fields
        try await db.schema
            .defineField("email", on: "users")
            .type(.string)
            .assert("string::is::email($value)")
            .execute()

        try await db.schema
            .defineField("username", on: "users")
            .type(.string)
            .assert("string::len($value) >= 3")
            .execute()

        try await db.schema
            .defineField("createdAt", on: "users")
            .type(.datetime)
            .default("time::now()")
            .execute()

        // Unique index on email
        try await db.schema
            .defineIndex("unique_email", on: "users")
            .fields("email")
            .unique()
            .execute()

        // Define posts table
        try await db.schema
            .defineTable("posts")
            .schemafull()
            .ifNotExists()
            .execute()

        try await db.schema
            .defineField("title", on: "posts")
            .type(.string)
            .execute()

        try await db.schema
            .defineField("content", on: "posts")
            .type(.string)
            .execute()

        try await db.schema
            .defineField("author", on: "posts")
            .type(.record(table: "users"))
            .execute()

        try await db.schema
            .defineField("tags", on: "posts")
            .type(.array(of: .string))
            .execute()

        try await db.schema
            .defineField("published", on: "posts")
            .type(.bool)
            .default("false")
            .execute()

        // Full-text search on content
        try await db.schema
            .defineIndex("ft_content", on: "posts")
            .fields("content")
            .fulltext(analyzer: "ascii")
            .execute()

        // Define authored relation
        try await db.schema
            .defineTable("authored")
            .relation(from: "users", to: "posts")
            .ifNotExists()
            .execute()

        try await db.schema
            .defineField("publishedAt", on: "authored")
            .type(.datetime)
            .execute()
    }

    func teardown() async throws {
        try await db.schema.removeTable("authored")
        try await db.schema.removeTable("posts")
        try await db.schema.removeTable("users")
    }
}
```

## Best Practices

### 1. Use ifNotExists for Idempotency

Make schema operations safe to run multiple times:

```swift
try await db.schema
    .defineTable("users")
    .ifNotExists()
    .execute()
```

### 2. Define Validation Rules

Catch data errors at the database level:

```swift
try await db.schema
    .defineField("age", on: "users")
    .type(.int)
    .assert("$value >= 0")
    .execute()
```

### 3. Use Type-Specific Indexes

Choose the right index type for your queries:

```swift
// Unique for constraints
try await db.schema
    .defineIndex("unique_email", on: "users")
    .fields("email")
    .unique()
    .execute()

// Full-text for search
try await db.schema
    .defineIndex("ft_posts", on: "posts")
    .fields("content")
    .fulltext(analyzer: "ascii")
    .execute()
```

### 4. Preview Before Execution

Use `toSurrealQL()` to verify complex definitions:

```swift
let builder = db.schema.defineField("metadata", on: "users").type(.object)
print(try builder.toSurrealQL())
```

### 5. Group Related Operations

Define all related schema elements together:

```swift
// Define table first
try await db.schema.defineTable("users").schemafull().execute()

// Then define all fields
try await db.schema.defineField("name", on: "users").type(.string).execute()
try await db.schema.defineField("email", on: "users").type(.string).execute()

// Finally, define indexes
try await db.schema.defineIndex("idx_email", on: "users").fields("email").execute()
```

## Error Handling

Schema operations can throw errors for various reasons:

```swift
do {
    try await db.schema
        .defineField("email", on: "users")
        .type(.string)
        .execute()
} catch let error as SurrealError {
    switch error {
    case .validationError(let message):
        print("Invalid identifier:", message)
    case .invalidQuery(let message):
        print("Malformed query:", message)
    default:
        print("Schema operation failed:", error)
    }
}
```

## Topics

### Builders

- ``SchemaBuilder``
- ``TableDefinitionBuilder``
- ``FieldDefinitionBuilder``
- ``IndexDefinitionBuilder``

### Type System

- ``FieldType``
- ``SchemaMode``
- ``TableType``
- ``IndexType``
- ``GeometryType``

### Related Documentation

- <doc:SchemaMacros>
