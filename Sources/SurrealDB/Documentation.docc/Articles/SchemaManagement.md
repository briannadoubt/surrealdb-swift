# Schema Management

Define and manage database schemas with compile-time safety using Swift macros and fluent builder APIs.

## Overview

SurrealDB Swift provides comprehensive schema management capabilities that allow you to define and manage database schemas with compile-time type safety. The system offers two complementary approaches:

1. **Automatic Schema Generation** - Use the `@Surreal` macro to automatically generate schemas from Swift types
2. **Manual Schema Building** - Use fluent builder APIs for fine-grained control

### Why Schema Management?

Schema management helps you:
- **Ensure data consistency** with schemafull table definitions
- **Catch errors early** with compile-time validation
- **Document your data model** with type-safe Swift code
- **Migrate safely** by previewing schema changes
- **Support graph relationships** with edge models

## Quick Start

Define a model with the `@Surreal` macro:

```swift
import SurrealDB

@Surreal
struct User {
    var name: String
    @Index(type: .unique) var email: String
    var age: Int?
    var createdAt: Date
}
```

The macro automatically generates:
- `id: RecordID?` property
- `tableName` static property
- Schema metadata for all fields
- Protocol conformances (`SurrealModel`, `Codable`, `Sendable`)

Create the schema with one line:

```swift
let db = try SurrealDB(url: "ws://localhost:8000/rpc")
try await db.connect()
try await db.use(namespace: "test", database: "test")

// Generate and execute the schema
try await db.defineTable(for: User.self, mode: .schemafull)
```

This generates and executes:
```sql
DEFINE TABLE user SCHEMAFULL;
DEFINE FIELD name ON TABLE user TYPE string;
DEFINE FIELD email ON TABLE user TYPE string;
DEFINE FIELD age ON TABLE user TYPE option<int>;
DEFINE FIELD createdAt ON TABLE user TYPE datetime;
DEFINE INDEX idx_email ON TABLE user FIELDS email UNIQUE;
```

## Schema Management Approaches

### Automatic with Macros

Use `@Surreal` for rapid development and type safety:

```swift
@Surreal(tableName: "users")
struct User {
    var name: String
    var email: String
}

try await db.defineTable(for: User.self, mode: .schemafull)
```

**Benefits:**
- Minimal boilerplate
- Compile-time type checking
- Automatic type mapping
- Property wrapper support

### Manual with Builders

Use fluent builders for fine-grained control:

```swift
// Define table
try await db.schema
    .defineTable("users")
    .schemafull()
    .ifNotExists()
    .execute()

// Define field with validation
try await db.schema
    .defineField("age", on: "users")
    .type(.int)
    .assert("$value >= 0 AND $value <= 150")
    .execute()
```

**Benefits:**
- Explicit control
- Custom validation rules
- Complex computed fields
- Migration-friendly

## Key Features

### Compile-Time Safety

The `@Surreal` macro analyzes your types at compile-time using SwiftSyntax:
- Zero runtime overhead
- Full type information in static descriptors
- Catches type mismatches early

### Comprehensive Type System

Support for all SurrealDB types:
- **Primitives**: string, int, float, bool, datetime, uuid, bytes
- **Collections**: array<T>, set<T>
- **Special**: option<T> (nullable), record<table>, geometry<type>
- **Nested**: array<option<int>>, array<record<users>>

### Dry Run Mode

Preview SQL before execution:

```swift
let statements = try await db.defineTable(
    for: User.self,
    mode: .schemafull,
    execute: false  // Don't execute, just return SQL
)

for statement in statements {
    print(statement)
}
```

### Edge Model Support

First-class support for graph relationships:

```swift
@SurrealEdge(from: User.self, to: Post.self)
struct Authored {
    var publishedAt: Date
}

try await db.defineEdge(for: Authored.self, mode: .schemafull)
```

### Property Wrapper Integration

Use property wrappers for schema customization:
- `@Index(type: .unique)` - Define field indexes
- `@Computed` - Skip database-calculated fields
- `@Relation` - Client-side relationship helpers

## Schema Modes

### Schemafull

Enforce strict schema validation:

```swift
try await db.defineTable(for: User.self, mode: .schemafull)
```

- Only defined fields are allowed
- Field types are enforced
- Best for structured data

### Schemaless

Allow flexible schema:

```swift
try await db.defineTable(for: User.self, mode: .schemaless)
```

- Undefined fields are permitted
- Field types are suggested but not enforced
- Best for unstructured or evolving data

## Topics

### Getting Started
- <doc:SchemaMacros>
- <doc:SchemaBuilders>

### Advanced Topics
- <doc:SchemaTypes>
- <doc:SchemaIntrospection>

### API Reference
- ``SurrealDB/defineTable(for:mode:execute:)``
- ``SurrealDB/defineEdge(for:mode:execute:)``
- ``SchemaBuilder``
- ``TableDefinitionBuilder``
- ``FieldDefinitionBuilder``
- ``IndexDefinitionBuilder``
