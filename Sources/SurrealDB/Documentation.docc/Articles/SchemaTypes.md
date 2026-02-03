# Schema Types

Understanding SurrealDB's comprehensive type system and how Swift types map to database types.

## Overview

SurrealDB Swift provides a rich type system that maps Swift types to SurrealDB's native types. The `FieldType` enum represents all available SurrealDB types, from simple primitives to complex nested structures. Understanding this type system is essential for effective schema management and data modeling.

The type system ensures:
- **Type safety** with compile-time validation
- **Automatic conversion** between Swift and SurrealDB types
- **Rich data modeling** with nested and parameterized types
- **Clear documentation** through explicit type definitions

## FieldType Enum

The `FieldType` enum is the foundation of the type system. It's an indirect enum that supports recursive type definitions, enabling complex nested structures like `array<option<record<users>>>`.

```swift
public indirect enum FieldType: Sendable, Equatable, Codable, Hashable {
    // All SurrealDB types
}
```

Each case generates appropriate SurrealQL when calling `toSurrealQL()`.

## Primitive Types

### String Type

Represents text data of any length.

```swift
let nameType = FieldType.string
print(nameType.toSurrealQL()) // "string"
```

**Swift mapping:**
- `String`

**Example usage:**
```swift
@Surreal
struct User {
    var name: String       // -> string
    var bio: String        // -> string
}
```

### Integer Types

Represents whole numbers.

```swift
let ageType = FieldType.int
print(ageType.toSurrealQL()) // "int"
```

**Swift mapping:**
- `Int`, `Int8`, `Int16`, `Int32`, `Int64`
- `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`

**Example usage:**
```swift
@Surreal
struct Product {
    var quantity: Int      // -> int
    var views: Int64       // -> int
}
```

### Float Types

Represents floating-point numbers with decimal precision.

```swift
let priceType = FieldType.float
print(priceType.toSurrealQL()) // "float"
```

**Swift mapping:**
- `Float`, `Float32`, `Float64`
- `Double`

**Example usage:**
```swift
@Surreal
struct Product {
    var price: Double      // -> float
    var weight: Float      // -> float
}
```

### Decimal Type

Represents high-precision decimal numbers for financial calculations.

```swift
let amountType = FieldType.decimal
print(amountType.toSurrealQL()) // "decimal"
```

**Best for:**
- Financial amounts
- Precise calculations
- When floating-point rounding is unacceptable

### Number Type

Generic number type accepting any numeric value.

```swift
let valueType = FieldType.number
print(valueType.toSurrealQL()) // "number"
```

Use when you need to accept both integers and floats in the same field.

### Boolean Type

Represents true/false values.

```swift
let activeType = FieldType.bool
print(activeType.toSurrealQL()) // "bool"
```

**Swift mapping:**
- `Bool`

**Example usage:**
```swift
@Surreal
struct Post {
    var published: Bool    // -> bool
    var featured: Bool     // -> bool
}
```

### DateTime Type

Represents date and time values with timezone support.

```swift
let createdType = FieldType.datetime
print(createdType.toSurrealQL()) // "datetime"
```

**Swift mapping:**
- `Date`

**Example usage:**
```swift
@Surreal
struct Event {
    var startTime: Date    // -> datetime
    var endTime: Date      // -> datetime
}
```

### Duration Type

Represents time intervals and durations.

```swift
let durationField = FieldType.duration
print(durationField.toSurrealQL()) // "duration"
```

**Use cases:**
- Time intervals
- Elapsed time
- TTL values

### UUID Type

Represents universally unique identifiers.

```swift
let idType = FieldType.uuid
print(idType.toSurrealQL()) // "uuid"
```

**Swift mapping:**
- `UUID`

**Example usage:**
```swift
@Surreal
struct Session {
    var sessionId: UUID    // -> uuid
}
```

### Bytes Type

Represents binary data.

```swift
let dataType = FieldType.bytes
print(dataType.toSurrealQL()) // "bytes"
```

**Swift mapping:**
- `Data`

**Use cases:**
- File contents
- Encrypted data
- Binary blobs

### Object Type

Represents arbitrary JSON objects or dictionaries.

```swift
let metadataType = FieldType.object
print(metadataType.toSurrealQL()) // "object"
```

**Swift mapping:**
- `Dictionary<String, Any>`
- Custom structs (when serialized)

**Example usage:**
```swift
@Surreal
struct Product {
    var metadata: [String: String]  // -> object
}
```

### Null Type

Explicitly represents null values.

```swift
let nullField = FieldType.null
print(nullField.toSurrealQL()) // "null"
```

Rarely used directly; prefer `option<T>` for nullable fields.

### Any Type

Accepts any value type.

```swift
let flexibleField = FieldType.any
print(flexibleField.toSurrealQL()) // "any"
```

Use when you need maximum flexibility, but loses type safety.

## Collection Types

### Array Type

Represents ordered lists of values of a specific type.

```swift
// Simple array
let tagsType = FieldType.array(of: .string)
print(tagsType.toSurrealQL()) // "array<string>"

// Array with max length constraint
let recentScores = FieldType.array(of: .int, maxLength: 10)
print(recentScores.toSurrealQL()) // "array<int, 10>"

// Nested arrays
let matrix = FieldType.array(of: .array(of: .int))
print(matrix.toSurrealQL()) // "array<array<int>>"
```

**Swift mapping:**
- `Array<T>`
- `[T]`

**Example usage:**
```swift
@Surreal
struct Article {
    var tags: [String]              // -> array<string>
    var scores: [Int]               // -> array<int>
    var comments: [Comment]         // -> array<object>
}
```

### Set Type

Represents unordered collections with unique values.

```swift
let categoriesType = FieldType.set(of: .string)
print(categoriesType.toSurrealQL()) // "set<string>"

let uniqueIds = FieldType.set(of: .uuid)
print(uniqueIds.toSurrealQL()) // "set<uuid>"
```

**Key differences from arrays:**
- Automatically removes duplicates
- Order is not guaranteed
- Better for membership testing

**Example usage:**
```swift
@Surreal
struct Product {
    // Categories should be unique
    var categories: Set<String>     // -> set<string>
}
```

## Special Types

### Option Type

Represents nullable/optional values.

```swift
let optionalAge = FieldType.option(of: .int)
print(optionalAge.toSurrealQL()) // "option<int>"

let optionalEmail = FieldType.option(of: .string)
print(optionalEmail.toSurrealQL()) // "option<string>"
```

**Swift mapping:**
- `Optional<T>`
- `T?`

**Example usage:**
```swift
@Surreal
struct User {
    var name: String           // -> string (required)
    var middleName: String?    // -> option<string> (optional)
    var age: Int?              // -> option<int> (optional)
}
```

### Record Type

Represents references to other records/tables.

```swift
// Generic record reference (any table)
let anyRecord = FieldType.record(table: nil)
print(anyRecord.toSurrealQL()) // "record"

// Specific table reference
let userRef = FieldType.record(table: "users")
print(userRef.toSurrealQL()) // "record<users>"

// Array of records
let authorRefs = FieldType.array(of: .record(table: "users"))
print(authorRefs.toSurrealQL()) // "array<record<users>>"
```

**Swift mapping:**
- `RecordID`

**Example usage:**
```swift
@Surreal
struct Post {
    var authorId: RecordID         // -> record
    var relatedPosts: [RecordID]   // -> array<record>
}

@Surreal
struct Comment {
    // Reference to specific table
    var userId: RecordID           // -> record<users>
    var postId: RecordID           // -> record<posts>
}
```

### Geometry Type

Represents geographic and geometric data using GeoJSON.

```swift
// Generic geometry
let location = FieldType.geometry(subtype: nil)
print(location.toSurrealQL()) // "geometry"

// Specific geometry types
let point = FieldType.geometry(subtype: .point)
print(point.toSurrealQL()) // "geometry<point>"

let polygon = FieldType.geometry(subtype: .polygon)
print(polygon.toSurrealQL()) // "geometry<polygon>"
```

**Available geometry subtypes:**
- `point` - Single coordinate
- `lineString` - Connected line segments
- `polygon` - Closed shape
- `multiPoint` - Multiple points
- `multiLineString` - Multiple lines
- `multiPolygon` - Multiple polygons
- `collection` - Mixed geometry collection

**Example usage:**
```swift
@Surreal
struct Location {
    var coordinates: Geometry      // -> geometry<point>
    var boundary: Geometry         // -> geometry<polygon>
}
```

### Range Type

Represents value intervals.

```swift
let rangeField = FieldType.range
print(rangeField.toSurrealQL()) // "range"
```

**Use cases:**
- Date ranges
- Number intervals
- Version ranges

### Regex Type

Represents regular expression patterns.

```swift
let patternField = FieldType.regex
print(patternField.toSurrealQL()) // "regex"
```

## Advanced Types

### Literal Type

Represents enum-like values with a fixed set of allowed strings.

```swift
// Single value
let statusActive = FieldType.literal(values: ["active"])
print(statusActive.toSurrealQL()) // "active"

// Multiple allowed values (enum-like)
let status = FieldType.literal(values: ["active", "inactive", "pending"])
print(status.toSurrealQL()) // "active" | "inactive" | "pending"

// Yes/No field
let confirmation = FieldType.literal(values: ["yes", "no"])
print(confirmation.toSurrealQL()) // "yes" | "no"
```

**Use cases:**
- Status fields
- Enum-like constraints
- Predefined options

**Example usage:**
```swift
try await db.schema
    .defineField("status", on: "users")
    .type(.literal(values: ["active", "inactive", "banned"]))
    .execute()
```

### Either Type

Represents union types allowing multiple type alternatives.

```swift
// Int or String
let flexibleId = FieldType.either([.int, .string])
print(flexibleId.toSurrealQL()) // "int | string"

// Multiple types
let value = FieldType.either([.int, .string, .bool])
print(value.toSurrealQL()) // "int | string | bool"

// Complex types
let reference = FieldType.either([
    .record(table: "users"),
    .uuid
])
print(reference.toSurrealQL()) // "record<users> | uuid"
```

**Use cases:**
- Polymorphic fields
- Migration compatibility
- Flexible data models

**Example usage:**
```swift
try await db.schema
    .defineField("identifier", on: "items")
    .type(.either([.uuid, .string]))
    .execute()
```

## Nested Types

The type system supports arbitrary nesting for complex data structures.

### Array of Optional Values

```swift
let optionalStrings = FieldType.array(of: .option(of: .string))
print(optionalStrings.toSurrealQL()) // "array<option<string>>"
```

Allows arrays that can contain null values:
```json
["hello", null, "world"]
```

### Optional Array

```swift
let optionalArray = FieldType.option(of: .array(of: .int))
print(optionalArray.toSurrealQL()) // "option<array<int>>"
```

The entire array can be null:
```json
null  // or [1, 2, 3]
```

### Array of Records

```swift
let userRefs = FieldType.array(of: .record(table: "users"))
print(userRefs.toSurrealQL()) // "array<record<users>>"
```

**Example:**
```swift
@Surreal
struct Team {
    var members: [RecordID]  // -> array<record<users>>
}
```

### Complex Nested Example

```swift
let complex = FieldType.option(of:
    .array(of:
        .either([
            .record(table: "users"),
            .string
        ])
    )
)
print(complex.toSurrealQL())
// "option<array<record<users> | string>>"
```

This represents an optional array where each element can be either a user record or a string.

### Nested Arrays with Length Constraints

```swift
let matrix = FieldType.array(
    of: .array(of: .int, maxLength: 3),
    maxLength: 5
)
print(matrix.toSurrealQL()) // "array<array<int, 3>, 5>"
```

Represents a 5x3 matrix of integers.

## Type Mapping Reference

### Swift to SurrealDB Type Mapping

| Swift Type | SurrealDB Type | Notes |
|------------|----------------|-------|
| `String` | `string` | UTF-8 text |
| `Int`, `Int64` | `int` | Whole numbers |
| `Double`, `Float` | `float` | Floating-point |
| `Bool` | `bool` | True/false |
| `Date` | `datetime` | Timestamp with timezone |
| `UUID` | `uuid` | UUID v4 format |
| `Data` | `bytes` | Binary data |
| `[T]` | `array<T>` | Ordered list |
| `Set<T>` | `set<T>` | Unique values |
| `T?` | `option<T>` | Nullable |
| `RecordID` | `record` | Record reference |
| `Dictionary<String, Any>` | `object` | JSON object |

### Type Conversion Examples

```swift
// Swift model
@Surreal
struct User {
    var name: String              // string
    var age: Int                  // int
    var score: Double             // float
    var active: Bool              // bool
    var createdAt: Date           // datetime
    var sessionId: UUID           // uuid
    var avatar: Data              // bytes
    var tags: [String]            // array<string>
    var bio: String?              // option<string>
    var managerId: RecordID       // record
    var metadata: [String: Any]   // object
}
```

### Manual Type Definition

When using schema builders, specify types explicitly:

```swift
try await db.schema
    .defineField("email", on: "users")
    .type(.string)
    .execute()

try await db.schema
    .defineField("friends", on: "users")
    .type(.array(of: .record(table: "users")))
    .execute()

try await db.schema
    .defineField("settings", on: "users")
    .type(.object)
    .execute()
```

## Type Safety Best Practices

### 1. Use Specific Types

Prefer specific types over generic ones:

```swift
// Good - specific type
FieldType.int

// Avoid - too generic
FieldType.number
FieldType.any
```

### 2. Leverage Optional Types

Use `option<T>` instead of nullable fields:

```swift
// Good - explicit optional
FieldType.option(of: .string)

// Avoid - ambiguous
FieldType.string  // Is it required or optional?
```

### 3. Constrain Arrays

Use maxLength to prevent unbounded growth:

```swift
// Good - limited size
FieldType.array(of: .string, maxLength: 100)

// Risky - unlimited
FieldType.array(of: .string)
```

### 4. Type Record References

Specify table names for type safety:

```swift
// Good - typed reference
FieldType.record(table: "users")

// Less safe - any table
FieldType.record(table: nil)
```

### 5. Use Literal for Enums

Define allowed values for enum-like fields:

```swift
// Good - constrained values
FieldType.literal(values: ["draft", "published", "archived"])

// Avoid - no constraints
FieldType.string
```

## Complete Example

Here's a comprehensive example using various types:

```swift
@Surreal
struct BlogPost {
    // Primitives
    var title: String                    // string
    var content: String                  // string
    var viewCount: Int                   // int
    var rating: Double                   // float
    var published: Bool                  // bool
    var publishedAt: Date                // datetime

    // Optional fields
    var subtitle: String?                // option<string>
    var featuredImage: Data?             // option<bytes>

    // Collections
    var tags: [String]                   // array<string>
    var categories: Set<String>          // set<string>

    // References
    var authorId: RecordID               // record
    var relatedPosts: [RecordID]         // array<record>

    // Complex types
    var metadata: [String: String]       // object
    var location: Geometry?              // option<geometry>
}

// Define schema
try await db.defineTable(for: BlogPost.self, mode: .schemafull)
```

This generates:
```sql
DEFINE TABLE blog_post SCHEMAFULL;
DEFINE FIELD title ON TABLE blog_post TYPE string;
DEFINE FIELD content ON TABLE blog_post TYPE string;
DEFINE FIELD viewCount ON TABLE blog_post TYPE int;
DEFINE FIELD rating ON TABLE blog_post TYPE float;
DEFINE FIELD published ON TABLE blog_post TYPE bool;
DEFINE FIELD publishedAt ON TABLE blog_post TYPE datetime;
DEFINE FIELD subtitle ON TABLE blog_post TYPE option<string>;
DEFINE FIELD featuredImage ON TABLE blog_post TYPE option<bytes>;
DEFINE FIELD tags ON TABLE blog_post TYPE array<string>;
DEFINE FIELD categories ON TABLE blog_post TYPE set<string>;
DEFINE FIELD authorId ON TABLE blog_post TYPE record;
DEFINE FIELD relatedPosts ON TABLE blog_post TYPE array<record>;
DEFINE FIELD metadata ON TABLE blog_post TYPE object;
DEFINE FIELD location ON TABLE blog_post TYPE option<geometry>;
```

## Topics

### Related Documentation
- <doc:SchemaMacros>
- <doc:SchemaBuilders>

### API Reference
- ``FieldType``
- ``GeometryType``
- ``SchemaMode``
- ``TableType``
