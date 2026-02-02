# Schema Management Implementation

This document describes the implementation of Phase 4 (Schema Generation) and Phase 5 (Integration) from the schema management plan.

## Overview

The schema management system provides powerful, type-safe schema definition and management capabilities for SurrealDB, allowing developers to:

1. Generate schema definitions from Swift types
2. Execute or preview schema statements
3. Manage tables, edges, fields, and indexes
4. Introspect existing database schemas

## Phase 4: Schema Generation

### `Sources/SurrealDB/Schema/SchemaGenerator.swift`

The SchemaGenerator is responsible for converting Swift types and field definitions into SurrealQL DEFINE statements.

#### Key Features

- **Table Schema Generation**: Converts `SurrealModel` types to table definitions
- **Edge Schema Generation**: Converts `EdgeModel` types to relationship tables
- **Schema Mode Support**: Handles both `schemafull` and `schemaless` modes
- **Drop Support**: Optionally generates `REMOVE TABLE` statements
- **Type Mapping**: Maps Swift types to SurrealDB types

#### Main Methods

```swift
// Generate table schema for a SurrealModel
static func generateTableSchema<T: SurrealModel>(
    for type: T.Type,
    mode: SchemaMode = .schemafull,
    drop: Bool = false
) throws -> [String]

// Generate edge schema for an EdgeModel
static func generateEdgeSchema<T: EdgeModel>(
    for type: T.Type,
    mode: SchemaMode = .schemafull,
    drop: Bool = false
) throws -> [String]

// Generate schema with explicit field definitions
static func generateSchema(
    tableName: String,
    fields: [(name: String, type: String, optional: Bool)],
    mode: SchemaMode = .schemafull,
    drop: Bool = false
) -> [String]

// Map Swift types to SurrealDB types
static func mapSwiftType(_ swiftType: String) -> String
```

#### Example Output

For a `User` model:
```swift
struct User: SurrealModel {
    var id: RecordID?
    var name: String
    var email: String
    var age: Int
}
```

Generates:
```sql
DEFINE TABLE user SCHEMAFULL;
DEFINE FIELD name ON TABLE user TYPE string;
DEFINE FIELD email ON TABLE user TYPE string;
DEFINE FIELD age ON TABLE user TYPE int;
```

## Phase 5: Integration

### `Sources/SurrealDB/Client/SurrealDB+Schema.swift`

Extends the `SurrealDB` actor with schema management methods, providing seamless integration with the existing client API.

#### Key Features

- **Type-Safe Schema Definition**: Use Swift types to define schemas
- **Dry Run Mode**: Preview statements before execution
- **Flexible API**: Supports both type-based and explicit field definitions
- **Edge Support**: Handle EdgeModel's From/To associated types
- **Schema Introspection**: Query existing schema information

#### Main Methods

```swift
// Define table from SurrealModel type
func defineTable<T: SurrealModel>(
    for type: T.Type,
    mode: SchemaMode = .schemafull,
    drop: Bool = false,
    execute: Bool = true
) async throws -> [String]

// Define table with explicit fields
func defineTable(
    tableName: String,
    fields: [(name: String, type: String, optional: Bool)],
    mode: SchemaMode = .schemafull,
    drop: Bool = false,
    execute: Bool = true
) async throws -> [String]

// Define edge from EdgeModel type
func defineEdge<T: EdgeModel>(
    for type: T.Type,
    mode: SchemaMode = .schemafull,
    drop: Bool = false,
    execute: Bool = true
) async throws -> [String]

// Define edge with explicit constraints
func defineEdge(
    edgeName: String,
    from fromTable: String,
    to toTable: String,
    fields: [(name: String, type: String, optional: Bool)] = [],
    mode: SchemaMode = .schemafull,
    drop: Bool = false,
    execute: Bool = true
) async throws -> [String]

// Schema introspection
func describeTable(_ tableName: String) async throws -> SurrealValue
func listTables() async throws -> [String]
```

## Usage Examples

### Basic Table Definition

```swift
// Define a table from a model type
let statements = try await db.defineTable(for: User.self, mode: .schemafull)
// Executes immediately by default

// Dry run - preview statements without executing
let preview = try await db.defineTable(
    for: User.self,
    mode: .schemafull,
    execute: false
)
for statement in preview {
    print(statement)
}
```

### Edge Definition

```swift
struct Authored: EdgeModel {
    typealias From = User
    typealias To = Post
    var createdAt: String
    var role: String
}

// Define the edge schema
try await db.defineEdge(for: Authored.self, mode: .schemafull)
```

### Explicit Field Definitions

```swift
// Define schema without relying on type reflection
try await db.defineTable(
    tableName: "products",
    fields: [
        ("name", "string", false),      // required string
        ("price", "float", false),       // required float
        ("description", "string", true), // optional string
        ("stock", "int", false)          // required int
    ],
    mode: .schemafull
)
```

### Schema Introspection

```swift
// List all tables
let tables = try await db.listTables()
for table in tables {
    print(table)
}

// Get detailed table information
let info = try await db.describeTable("users")
print(info)
```

## Implementation Notes

### SchemaMode

The `SchemaMode` enum (defined in `SchemaTypes.swift`) controls schema enforcement:

- **`schemafull`**: Full schema enforcement - all fields must be defined
- **`schemaless`**: Flexible schema - allows undefined fields

### Type Mapping

The SchemaGenerator includes a type mapper that converts Swift types to SurrealDB types:

| Swift Type | SurrealDB Type |
|------------|----------------|
| String     | string         |
| Int        | int            |
| Double     | float          |
| Bool       | bool           |
| Date       | datetime       |
| UUID       | string         |
| Data       | bytes          |
| Array<T>   | array          |
| Dictionary | object         |

### Execute Parameter

All schema definition methods include an `execute` parameter:

- **`execute: true`** (default): Immediately execute the statements
- **`execute: false`**: Return statements without execution (dry run mode)

This allows developers to preview and validate schema changes before applying them.

### Error Handling

All methods use typed throws (`throws(SurrealError)`) for better error handling:

```swift
do {
    try await db.defineTable(for: User.self)
} catch let error as SurrealError {
    switch error {
    case .invalidQuery(let message):
        print("Invalid query: \(message)")
    case .encodingError(let message):
        print("Encoding error: \(message)")
    default:
        print("Error: \(error)")
    }
}
```

## Future Enhancements

### Macro Integration

The current implementation uses a simplified type extraction approach. Future versions will integrate with the `@Surreal` and `@SurrealEdge` macros to:

- Access compile-time type information via `SchemaDescriptor`
- Support property wrappers like `@Index`, `@Computed`, and `@Relation`
- Generate more sophisticated schema definitions

### Enhanced Type Mapping

Future enhancements will include:

- Support for generic types
- Custom type converters
- Nested object types
- Enum support

### Migration Support

Planned features include:

- Schema versioning
- Migration generation
- Automatic schema updates
- Conflict detection

## Testing

Tests are included in `Tests/SurrealDBTests/SchemaGeneratorTests.swift`:

- Table schema generation (schemafull/schemaless)
- Edge schema generation
- Drop statement generation
- Type mapping verification
- Explicit field definition

## Dependencies

The implementation builds on:

- `SchemaTypes.swift`: Foundation types (FieldType, SchemaMode, etc.)
- `SurrealValidator.swift`: Name validation
- `SurrealModel.swift`: Model protocols
- `SurrealValue.swift`: Type system

## Files Created

- `Sources/SurrealDB/Schema/SchemaGenerator.swift` (Phase 4)
- `Sources/SurrealDB/Client/SurrealDB+Schema.swift` (Phase 5)
- `Tests/SurrealDBTests/SchemaGeneratorTests.swift`
- `Examples/SchemaManagementExample.swift`

## Summary

This implementation provides a robust foundation for schema management in the SurrealDB Swift client. It offers both high-level type-safe APIs and low-level explicit control, with dry-run capabilities for safe schema evolution. The design is ready for future macro integration while remaining fully functional with the current reflection-based approach.
