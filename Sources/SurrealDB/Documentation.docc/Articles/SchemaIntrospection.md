# Schema Introspection

Discover, inspect, and understand your database schema at runtime.

## Overview

Schema introspection allows you to programmatically query and understand your SurrealDB database structure. This is useful for:

- **Database exploration** - Discovering tables and their structures
- **Schema validation** - Verifying that your database matches expectations
- **Migration planning** - Understanding current schema before making changes
- **Dynamic applications** - Building admin tools or schema visualizers
- **Testing and debugging** - Inspecting schema during development

SurrealDB Swift provides comprehensive introspection APIs that let you examine tables, fields, indexes, and other database metadata at runtime.

## Core Introspection Methods

### Listing All Tables

Retrieve all tables in the current database:

```swift
let db = try SurrealDB(url: "ws://localhost:8000/rpc")
try await db.connect()
try await db.use(namespace: "test", database: "test")

// Get all table names
let tables = try await db.listTables()
for table in tables {
    print("Found table: \(table)")
}
// Output:
// Found table: users
// Found table: posts
// Found table: comments
```

The `listTables()` method returns an array of table names as strings.

### Describing a Table

Get detailed information about a specific table's schema:

```swift
// Get comprehensive table information
let info = try await db.describeTable("users")
print(info)
```

The returned `SurrealValue` contains:

- **Fields** - All defined fields with their types and constraints
- **Indexes** - Index definitions on the table
- **Events** - Table-level event handlers
- **Schema mode** - Whether the table is schemafull or schemaless

### Accessing Schema Information

Extract specific details from table information:

```swift
let info = try await db.describeTable("users")

// Parse the result
if case .object(let tableInfo) = info {
    // Get fields
    if case .object(let fields) = tableInfo["fd"] {
        print("Fields:")
        for (name, definition) in fields {
            print("  - \(name): \(definition)")
        }
    }

    // Get indexes
    if case .object(let indexes) = tableInfo["ix"] {
        print("\nIndexes:")
        for (name, definition) in indexes {
            print("  - \(name): \(definition)")
        }
    }
}
```

## Database-Level Introspection

### Getting Database Information

Retrieve comprehensive database metadata:

```swift
// Using SchemaBuilder
let dbInfo = try await db.schema.info()

// Parse database information
if case .object(let info) = dbInfo {
    // Get all tables
    if case .object(let tables) = info["tb"] {
        print("Tables: \(tables.keys)")
    }

    // Get analyzers
    if case .object(let analyzers) = info["az"] {
        print("Analyzers: \(analyzers.keys)")
    }

    // Get functions
    if case .object(let functions) = info["fc"] {
        print("Functions: \(functions.keys)")
    }
}
```

Database info includes:

- **Tables (tb)** - All table definitions
- **Analyzers (az)** - Text analyzers
- **Functions (fc)** - Stored functions
- **Params (pa)** - Database parameters
- **Scopes (sc)** - Authentication scopes
- **Tokens (tk)** - Access tokens

### Alternative Table Info Method

Use `SchemaBuilder` for consistent API:

```swift
// Get table info via SchemaBuilder
let tableInfo = try await db.schema.infoForTable("users")
print(tableInfo)
```

This is equivalent to `describeTable()` but uses the fluent schema API.

## Dry Run Mode for Schema Changes

Before applying schema changes, preview the generated SQL statements:

```swift
@Surreal
struct User {
    var name: String
    @Index(type: .unique) var email: String
    var age: Int?
}

// Preview schema without executing
let statements = try await db.defineTable(
    for: User.self,
    mode: .schemafull,
    execute: false  // Don't execute - just return SQL
)

print("Schema statements that would be executed:")
for statement in statements {
    print(statement)
}
// Output:
// DEFINE TABLE user SCHEMAFULL;
// DEFINE FIELD name ON TABLE user TYPE string;
// DEFINE FIELD email ON TABLE user TYPE string;
// DEFINE FIELD age ON TABLE user TYPE option<int>;
// DEFINE INDEX idx_email ON TABLE user FIELDS email UNIQUE;

// Review the statements, then execute
try await db.defineTable(for: User.self, mode: .schemafull)
```

Dry run mode is essential for:

- **Migration planning** - See exactly what will change
- **Code review** - Share SQL changes with team
- **Testing** - Validate schema generation logic
- **Learning** - Understand how Swift types map to SurrealQL

## Practical Use Cases

### Building a Schema Validator

Verify that your database schema matches expectations:

```swift
func validateSchema() async throws {
    let db = try SurrealDB(url: "ws://localhost:8000/rpc")
    try await db.connect()
    try await db.use(namespace: "prod", database: "app")

    // Check required tables exist
    let tables = try await db.listTables()
    let requiredTables = ["users", "posts", "comments"]

    for table in requiredTables {
        guard tables.contains(table) else {
            throw SchemaError.missingTable(table)
        }
    }

    // Verify users table structure
    let userInfo = try await db.describeTable("users")
    if case .object(let info) = userInfo,
       case .object(let fields) = info["fd"] {
        // Ensure email field exists and has unique index
        guard fields["email"] != nil else {
            throw SchemaError.missingField("email", table: "users")
        }
    }

    print("Schema validation passed")
}

enum SchemaError: Error {
    case missingTable(String)
    case missingField(String, table: String)
}
```

### Creating a Schema Documentation Tool

Generate documentation from your database schema:

```swift
func documentSchema() async throws -> String {
    let db = try SurrealDB(url: "ws://localhost:8000/rpc")
    try await db.connect()
    try await db.use(namespace: "docs", database: "app")

    var documentation = "# Database Schema\n\n"

    let tables = try await db.listTables()

    for tableName in tables.sorted() {
        documentation += "## Table: \(tableName)\n\n"

        let info = try await db.describeTable(tableName)

        if case .object(let tableInfo) = info {
            // Document fields
            if case .object(let fields) = tableInfo["fd"] {
                documentation += "### Fields\n\n"
                for (name, definition) in fields.sorted(by: { $0.key < $1.key }) {
                    documentation += "- **\(name)**: \(definition)\n"
                }
                documentation += "\n"
            }

            // Document indexes
            if case .object(let indexes) = tableInfo["ix"] {
                documentation += "### Indexes\n\n"
                for (name, definition) in indexes.sorted(by: { $0.key < $1.key }) {
                    documentation += "- **\(name)**: \(definition)\n"
                }
                documentation += "\n"
            }
        }
    }

    return documentation
}
```

### Detecting Schema Drift

Compare expected schema with actual database:

```swift
func detectSchemaDrift() async throws {
    let db = try SurrealDB(url: "ws://localhost:8000/rpc")
    try await db.connect()
    try await db.use(namespace: "prod", database: "app")

    // Generate expected schema (dry run)
    let expectedStatements = try await db.defineTable(
        for: User.self,
        mode: .schemafull,
        execute: false
    )

    // Get actual schema
    let actualInfo = try await db.describeTable("users")

    // Compare expected vs actual
    // (You would parse and compare the structures here)
    print("Expected schema:")
    expectedStatements.forEach { print($0) }

    print("\nActual schema:")
    print(actualInfo)
}
```

### Building an Admin Dashboard

Create dynamic schema explorers:

```swift
struct SchemaExplorer {
    let db: SurrealDB

    func getTables() async throws -> [String] {
        try await db.listTables()
    }

    func getTableDetails(_ tableName: String) async throws -> TableDetails {
        let info = try await db.describeTable(tableName)

        // Parse and convert to structured data
        guard case .object(let tableInfo) = info else {
            throw ExplorerError.invalidTableInfo
        }

        var fields: [FieldInfo] = []
        if case .object(let fieldDefs) = tableInfo["fd"] {
            fields = fieldDefs.map { name, def in
                FieldInfo(name: name, definition: "\(def)")
            }
        }

        var indexes: [IndexInfo] = []
        if case .object(let indexDefs) = tableInfo["ix"] {
            indexes = indexDefs.map { name, def in
                IndexInfo(name: name, definition: "\(def)")
            }
        }

        return TableDetails(
            name: tableName,
            fields: fields,
            indexes: indexes
        )
    }
}

struct TableDetails {
    let name: String
    let fields: [FieldInfo]
    let indexes: [IndexInfo]
}

struct FieldInfo {
    let name: String
    let definition: String
}

struct IndexInfo {
    let name: String
    let definition: String
}

enum ExplorerError: Error {
    case invalidTableInfo
}
```

## Testing with Schema Introspection

Verify schema in integration tests:

```swift
import Testing
@testable import SurrealDB

@Test("Schema is created correctly")
func testSchemaCreation() async throws {
    let db = try SurrealDB(url: "ws://localhost:8000/rpc")
    try await db.connect()
    try await db.use(namespace: "test", database: "test")

    // Define schema
    try await db.defineTable(for: User.self, mode: .schemafull)

    // Verify table exists
    let tables = try await db.listTables()
    #expect(tables.contains("user"))

    // Verify table structure
    let info = try await db.describeTable("user")
    #expect(info != .null)

    if case .object(let tableInfo) = info,
       case .object(let fields) = tableInfo["fd"] {
        // Verify required fields exist
        #expect(fields["name"] != nil)
        #expect(fields["email"] != nil)
    }
}
```

## Understanding INFO Output

SurrealDB's `INFO` command returns structured information about database objects. The result follows this structure:

### Database Info Structure

```swift
{
    "az": {},      // Analyzers
    "fc": {},      // Functions
    "pa": {},      // Parameters
    "sc": {},      // Scopes
    "tb": {        // Tables
        "users": "DEFINE TABLE users SCHEMAFULL;",
        "posts": "DEFINE TABLE posts SCHEMALESS;"
    },
    "tk": {}       // Tokens
}
```

### Table Info Structure

```swift
{
    "ev": {},      // Events
    "fd": {        // Fields
        "name": "DEFINE FIELD name ON TABLE users TYPE string;",
        "email": "DEFINE FIELD email ON TABLE users TYPE string;"
    },
    "ft": {},      // Full-text indexes
    "ix": {        // Indexes
        "idx_email": "DEFINE INDEX idx_email ON TABLE users FIELDS email UNIQUE;"
    },
    "tb": "DEFINE TABLE users SCHEMAFULL;"  // Table definition
}
```

## Best Practices

### Use Introspection for Development

Enable schema inspection during development:

```swift
#if DEBUG
func debugSchema() async throws {
    let tables = try await db.listTables()
    print("Available tables: \(tables)")

    for table in tables {
        let info = try await db.describeTable(table)
        print("\n\(table) schema:")
        print(info)
    }
}
#endif
```

### Always Use Dry Run for Migrations

Never apply schema changes blindly:

```swift
// ❌ Bad: Execute without review
try await db.defineTable(for: User.self)

// ✅ Good: Review first
let statements = try await db.defineTable(for: User.self, execute: false)
print("Will execute:")
statements.forEach { print($0) }

// Require confirmation
let proceed = confirm("Apply these changes?")
if proceed {
    try await db.defineTable(for: User.self)
}
```

### Cache Introspection Results

Schema doesn't change often - cache when appropriate:

```swift
actor SchemaCache {
    private var tableCache: [String: SurrealValue] = [:]
    private let db: SurrealDB

    init(db: SurrealDB) {
        self.db = db
    }

    func getTableInfo(_ tableName: String) async throws -> SurrealValue {
        if let cached = tableCache[tableName] {
            return cached
        }

        let info = try await db.describeTable(tableName)
        tableCache[tableName] = info
        return info
    }

    func invalidateCache() {
        tableCache.removeAll()
    }
}
```

### Combine with Schema Generation

Use introspection to verify generated schemas:

```swift
func createAndVerifySchema() async throws {
    // Generate schema
    try await db.defineTable(for: User.self, mode: .schemafull)

    // Verify it was created correctly
    let info = try await db.describeTable("user")

    guard case .object(let tableInfo) = info,
          case .object(let fields) = tableInfo["fd"] else {
        throw SchemaError.verificationFailed
    }

    // Ensure all expected fields exist
    let requiredFields = ["name", "email"]
    for field in requiredFields {
        guard fields[field] != nil else {
            throw SchemaError.missingExpectedField(field)
        }
    }

    print("Schema created and verified successfully")
}
```

## Topics

### Schema Introspection Methods

- ``SurrealDB/listTables()``
- ``SurrealDB/describeTable(_:)``
- ``SchemaBuilder/info()``
- ``SchemaBuilder/infoForTable(_:)``

### Schema Definition Methods

- ``SurrealDB/defineTable(for:mode:drop:execute:)``
- ``SurrealDB/defineTable(tableName:fields:mode:drop:execute:)``
- ``SurrealDB/defineEdge(for:mode:drop:execute:)``

### Related Documentation

- <doc:SchemaManagement>
- <doc:SchemaMacros>
- <doc:SchemaBuilders>

## See Also

- [SurrealDB INFO Documentation](https://surrealdb.com/docs/surrealql/statements/info)
- [SurrealDB Schema Documentation](https://surrealdb.com/docs/surrealql/statements/define)
