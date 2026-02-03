# Schema Macros

Automatically generate database schemas from Swift types using the `@Surreal` and `@SurrealEdge` macros.

## Overview

Schema macros provide compile-time code generation that automatically creates database schema definitions from your Swift types. This eliminates boilerplate, ensures type safety, and keeps your schema in sync with your code.

## @Surreal Macro

The `@Surreal` macro transforms a struct into a complete SurrealDB model with automatic schema generation.

### Basic Usage

```swift
@Surreal
struct User {
    var name: String
    var email: String
    var age: Int
}
```

The macro automatically generates:

```swift
struct User {
    var id: RecordID? = nil          // Added by macro
    var name: String
    var email: String
    var age: Int

    static let tableName = "user"     // Added by macro

    static let _schemaDescriptor = SchemaDescriptor(  // Added by macro
        tableName: "user",
        fields: [
            FieldDescriptor(name: "name", type: .string, isOptional: false),
            FieldDescriptor(name: "email", type: .string, isOptional: false),
            FieldDescriptor(name: "age", type: .int, isOptional: false)
        ]
    )
}

extension User: SurrealModel, Codable, Sendable {}  // Added by macro
```

### Custom Table Name

Override the default table name:

```swift
@Surreal(tableName: "users")
struct User {
    var name: String
}

print(User.tableName)  // "users"
```

### Optional Fields

The macro automatically detects optional types:

```swift
@Surreal
struct User {
    var name: String        // Required: string
    var age: Int?           // Optional: option<int>
    var bio: String?        // Optional: option<string>
}
```

### Collections

Arrays and sets are automatically mapped:

```swift
@Surreal
struct Post {
    var title: String
    var tags: [String]           // array<string>
    var categories: Set<String>  // set<string>
}
```

### Date and Time

Foundation types are automatically converted:

```swift
@Surreal
struct Event {
    var name: String
    var startTime: Date      // datetime
    var duration: TimeInterval
}
```

### Record References

Use `RecordID` for type-safe foreign keys:

```swift
@Surreal
struct Post {
    var title: String
    var author: RecordID<User>    // record<user>
    var reviewers: [RecordID<User>]  // array<record<user>>
}
```

## Property Wrappers

Enhance fields with property wrappers:

### @Index

Define indexes on fields:

```swift
@Surreal
struct User {
    var name: String
    @Index(type: .unique) var email: String
    @Index(type: .fulltext) var bio: String
}

try await db.defineTable(for: User.self, mode: .schemafull)
// Generates: DEFINE INDEX idx_email ON TABLE user FIELDS email UNIQUE
//            DEFINE INDEX idx_bio ON TABLE user FIELDS bio FULLTEXT
```

Index types:
- `.standard` - Regular index
- `.unique` - Unique constraint
- `.fulltext` - Full-text search
- `.search` - Search with analyzer

### @Computed

Skip fields that are computed by the database:

```swift
@Surreal
struct User {
    var firstName: String
    var lastName: String
    @Computed var fullName: String  // Skipped in schema
}
```

Computed fields are not included in DEFINE FIELD statements since they're calculated by the database using VALUE clauses.

### @Relation

Mark client-side relationship helpers (not included in schema):

```swift
@Surreal
struct Post {
    var title: String
    @Relation var author: User?  // Client-side only
    @Relation var comments: [Comment]  // Client-side only
}
```

`@Relation` properties are for client-side convenience and don't generate schema fields. Use edge models for actual graph relationships.

## @SurrealEdge Macro

The `@SurrealEdge` macro creates graph relationship models:

### Basic Edge

```swift
@SurrealEdge(from: User.self, to: Post.self)
struct Authored {
    var publishedAt: Date
    var role: String
}
```

The macro generates:

```swift
struct Authored {
    typealias From = User       // Added by macro
    typealias To = Post         // Added by macro
    var id: RecordID? = nil     // Added by macro
    var publishedAt: Date
    var role: String

    static let edgeName = "authored"  // Added by macro

    static let _schemaDescriptor = SchemaDescriptor(  // Added by macro
        tableName: "authored",
        fields: [
            FieldDescriptor(name: "publishedAt", type: .datetime, isOptional: false),
            FieldDescriptor(name: "role", type: .string, isOptional: false)
        ],
        isEdge: true,
        edgeFrom: "user",
        edgeTo: "post"
    )
}

extension Authored: EdgeModel, Codable, Sendable {}  // Added by macro
```

### Custom Edge Name

```swift
@SurrealEdge(edgeName: "created", from: User.self, to: Post.self)
struct Created {
    var timestamp: Date
}

print(Created.edgeName)  // "created"
```

### Creating the Schema

```swift
try await db.defineEdge(for: Authored.self, mode: .schemafull)
```

Generates:
```sql
DEFINE TABLE authored TYPE RELATION FROM user TO post SCHEMAFULL;
DEFINE FIELD publishedAt ON TABLE authored TYPE datetime;
DEFINE FIELD role ON TABLE authored TYPE string;
```

## Type Mapping

The macro automatically maps Swift types to SurrealDB types:

| Swift Type | SurrealDB Type | Example |
|------------|----------------|---------|
| `String` | `string` | `"hello"` |
| `Int`, `Int64`, `UInt` | `int` | `42` |
| `Float`, `Double` | `float` | `3.14` |
| `Bool` | `bool` | `true` |
| `Date` | `datetime` | ISO 8601 |
| `UUID` | `uuid` | UUID v4 |
| `Data` | `bytes` | Binary |
| `Decimal` | `decimal` | Precise |
| `T?` | `option<T>` | Nullable |
| `[T]` | `array<T>` | List |
| `Set<T>` | `set<T>` | Unique |
| `RecordID<T>` | `record<table>` | Reference |
| `Dictionary` | `object` | JSON |
| Custom struct | `object` | JSON |

## Advanced Features

### Nested Types

The macro handles nested generic types:

```swift
@Surreal
struct User {
    var name: String
    var emails: [String]?                    // option<array<string>>
    var friends: [RecordID<User>]            // array<record<user>>
    var preferences: [String: String]?       // option<object>
}
```

### Multiple Models

Define multiple related models:

```swift
@Surreal
struct User {
    var name: String
}

@Surreal
struct Post {
    var title: String
    var author: RecordID<User>
}

@SurrealEdge(from: User.self, to: Post.self)
struct Authored {
    var publishedAt: Date
}

// Create all schemas
try await db.defineTable(for: User.self, mode: .schemafull)
try await db.defineTable(for: Post.self, mode: .schemafull)
try await db.defineEdge(for: Authored.self, mode: .schemafull)
```

## Limitations

The macro has some limitations:

1. **Struct only** - Classes are not supported
2. **Stored properties** - Only stored properties are included
3. **Simple types** - Complex generic types may not map perfectly
4. **No inheritance** - Struct inheritance is not supported

For complex scenarios, use the manual builder API.

## Best Practices

### Do's

✅ Use `@Surreal` for standard models
✅ Use `@SurrealEdge` for relationships
✅ Use property wrappers for schema customization
✅ Preview schema with `execute: false`
✅ Use explicit types for clarity

### Don'ts

❌ Don't mix manual and automatic schema for same table
❌ Don't use on classes or protocols
❌ Don't rely on type inference in stored properties
❌ Don't forget to handle migration for existing tables

## Troubleshooting

### "Macro expansion error"

Ensure SwiftSyntax is properly configured in Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0")
]
```

### "Type not supported"

Some complex generic types may not be supported. Use explicit type annotation or the manual builder API.

### "Table already exists"

Use `execute: false` for dry run or manually drop the table first:

```swift
try await db.schema.removeTable("user")
try await db.defineTable(for: User.self, mode: .schemafull)
```

## See Also

- <doc:SchemaManagement>
- <doc:SchemaBuilders>
- <doc:SchemaTypes>
