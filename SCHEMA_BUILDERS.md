# Schema Builder API - Phase 3 Implementation

This document provides an overview of the schema builder fluent API implementation for SurrealDB Swift client.

## Overview

The schema builder API provides a type-safe, fluent interface for defining database schemas programmatically. It consists of four main components:

1. **SchemaBuilder** - Entry point for schema operations
2. **TableDefinitionBuilder** - For defining tables
3. **FieldDefinitionBuilder** - For defining fields
4. **IndexDefinitionBuilder** - For defining indexes

## Architecture

### Foundation Types

Located in `Sources/SurrealDB/Schema/SchemaTypes.swift`:

- `SchemaMode` - `.schemafull` or `.schemaless`
- `TableType` - `.normal` or `.relation(from:to:)`
- `FieldType` - All SurrealDB field types with nested support
- `IndexType` - `.standard`, `.unique`, `.fulltext`, `.search`
- `GeometryType` - Geometry subtypes

### Builders

All builders use copy-on-write for immutability and are `Sendable` for thread safety.

## Usage Examples

### Accessing the Schema API

```swift
let db = SurrealDB(url: "ws://localhost:8000/rpc")
try await db.connect()
try await db.use(namespace: "test", database: "test")

// Access via the schema property
let schema = db.schema
```

### Defining Tables

```swift
// Basic table
try await db.schema
    .defineTable("users")
    .execute()

// Schemafull table
try await db.schema
    .defineTable("users")
    .schemafull()
    .execute()

// Relation table
try await db.schema
    .defineTable("follows")
    .relation(from: "users", to: "users")
    .execute()

// With IF NOT EXISTS
try await db.schema
    .defineTable("users")
    .schemafull()
    .ifNotExists()
    .execute()

// Drop table
try await db.schema
    .defineTable("old_users")
    .drop()
    .execute()
```

### Defining Fields

```swift
// Basic field with type
try await db.schema
    .defineField("email", on: "users")
    .type(.string)
    .execute()

// Field with default value
try await db.schema
    .defineField("created_at", on: "users")
    .type(.datetime)
    .default("time::now()")
    .execute()

// Field with assertion (validation)
try await db.schema
    .defineField("age", on: "users")
    .type(.int)
    .assert("$value >= 0 AND $value <= 150")
    .execute()

// Computed field
try await db.schema
    .defineField("full_name", on: "users")
    .type(.string)
    .value("string::concat($this.first_name, ' ', $this.last_name)")
    .execute()

// Optional field
try await db.schema
    .defineField("bio", on: "users")
    .type(.option(of: .string))
    .execute()

// Array field
try await db.schema
    .defineField("tags", on: "posts")
    .type(.array(of: .string))
    .execute()

// Record reference
try await db.schema
    .defineField("author", on: "posts")
    .type(.record(table: "users"))
    .execute()

// Flexible field (allows nested fields)
try await db.schema
    .defineField("metadata", on: "users")
    .type(.object)
    .flexible()
    .execute()
```

### Defining Indexes

```swift
// Standard index
try await db.schema
    .defineIndex("idx_email", on: "users")
    .fields("email")
    .execute()

// Unique index
try await db.schema
    .defineIndex("unique_email", on: "users")
    .fields("email")
    .unique()
    .execute()

// Multi-field index
try await db.schema
    .defineIndex("idx_name", on: "users")
    .fields("first_name", "last_name")
    .execute()

// Full-text search index
try await db.schema
    .defineIndex("ft_content", on: "posts")
    .fields("content")
    .fulltext(analyzer: "ascii")
    .execute()

// Search index
try await db.schema
    .defineIndex("search_title", on: "posts")
    .fields("title")
    .search(analyzer: "ascii")
    .execute()

// With IF NOT EXISTS
try await db.schema
    .defineIndex("idx_email", on: "users")
    .fields("email")
    .ifNotExists()
    .execute()
```

### Removal Operations

```swift
// Remove table
try await db.schema.removeTable("old_users")

// Remove field
try await db.schema.removeField("old_column", from: "users")

// Remove index
try await db.schema.removeIndex("old_idx", from: "users")
```

### Info Operations

```swift
// Get database schema info
let dbInfo = try await db.schema.info()

// Get table info
let tableInfo = try await db.schema.infoForTable("users")
```

## SurrealQL Generation

All builders provide a `toSurrealQL()` method for inspecting the generated query:

```swift
let builder = db.schema
    .defineTable("users")
    .schemafull()

let sql = try builder.toSurrealQL()
// "DEFINE TABLE users SCHEMAFULL"
```

## Validation

All identifiers (table names, field names, index names) are validated using `SurrealValidator`:

- Must not be empty
- Must start with a letter or underscore
- Can contain letters, numbers, and underscores
- Cannot be reserved keywords
- Field names support dot notation for nested fields

Invalid identifiers throw `SurrealError.schemaValidation`.

## Type System

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

```swift
.array(of: .option(of: .string))        // array<option<string>>
.option(of: .array(of: .int))           // option<array<int>>
.array(of: .record(table: "users"))     // array<record<users>>
```

## Implementation Details

### Copy-on-Write Pattern

All builders use copy-on-write for immutability:

```swift
let builder1 = db.schema.defineTable("users")
let builder2 = builder1.schemafull()  // New instance
// builder1 is unchanged
```

### Thread Safety

All builders and types are marked `Sendable` for safe concurrent access.

### Async Execution

The `execute()` method is async and returns the first result from the query:

```swift
@discardableResult
public func execute() async throws -> SurrealValue {
    let sql = try toSurrealQL()
    let results = try await client.query(sql)
    return results.first ?? .null
}
```

## Files Created

### Core Schema Types
- `Sources/SurrealDB/Schema/SchemaTypes.swift` - Foundation types (SchemaMode, TableType, FieldType, IndexType, GeometryType)
- `Sources/SurrealDB/Schema/TypeMapper.swift` - Swift to SurrealDB type mapping

### Builders
- `Sources/SurrealDB/Schema/SchemaBuilder.swift` - Entry point
- `Sources/SurrealDB/Schema/TableDefinitionBuilder.swift` - Table definitions
- `Sources/SurrealDB/Schema/FieldDefinitionBuilder.swift` - Field definitions
- `Sources/SurrealDB/Schema/IndexDefinitionBuilder.swift` - Index definitions

### Integration
- `Sources/SurrealDB/Client/SurrealDB.swift` - Added `schema` property
- `Sources/SurrealDB/Core/Validation.swift` - Enhanced with index validation
- `Sources/SurrealDB/Core/SurrealError.swift` - Added schema error cases

### Tests
- `Tests/SurrealDBTests/Schema/SchemaBuilderTests.swift` - Comprehensive builder tests
- `Tests/SurrealDBTests/Schema/SchemaTypesTests.swift` - Type system tests

## Error Handling

The builders throw `SurrealError` for:

- `schemaValidation` - Invalid identifier names
- `invalidQuery` - Malformed queries
- Other transport/connection errors from execution

## Future Enhancements

Potential improvements for future versions:

1. **Batch Operations** - Define multiple schema elements in one transaction
2. **Schema Diffing** - Compare current schema with desired schema
3. **Migrations** - Automatic schema migration generation
4. **Schema from Types** - Generate schema from Swift types using macros
5. **Permissions** - Add support for PERMISSIONS clauses
6. **Events** - Add support for DEFINE EVENT
