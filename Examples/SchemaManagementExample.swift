import Foundation
import SurrealDB

// MARK: - Example: Schema Management with Phase 4 & 5

// This example demonstrates the schema generation and integration features
// implemented in Phase 4 (Schema Generation) and Phase 5 (Integration).

// MARK: - Define Models

struct User: SurrealModel {
    var id: RecordID?
    var name: String
    var email: String
    var age: Int
}

struct Post: SurrealModel {
    var id: RecordID?
    var title: String
    var content: String
    var published: Bool
}

struct Authored: EdgeModel {
    typealias From = User
    typealias To = Post
    var createdAt: String
    var role: String
}

// MARK: - Example Usage

func schemaGenerationExamples(db: SurrealDB) async throws {
    print("=== Schema Generation Examples ===\n")

    // Example 1: Generate table schema (dry run)
    print("1. Generate User table schema (dry run):")
    let userStatements = try await db.defineTable(
        for: User.self,
        mode: .schemafull,
        execute: false  // Dry run - just return statements
    )
    for statement in userStatements {
        print("  \(statement)")
    }
    print()

    // Example 2: Generate and execute table schema
    print("2. Generate and execute Post table schema:")
    _ = try await db.defineTable(
        for: Post.self,
        mode: .schemafull,
        execute: true  // Execute the statements
    )
    print("  ✓ Post table created")
    print()

    // Example 3: Generate edge schema
    print("3. Generate Authored edge schema (dry run):")
    let authoredStatements = try await db.defineEdge(
        for: Authored.self,
        mode: .schemafull,
        execute: false
    )
    for statement in authoredStatements {
        print("  \(statement)")
    }
    print()
}

func explicitSchemaExamples(db: SurrealDB) async throws {
    // Example 4: Generate schema with explicit fields
    print("4. Generate schema with explicit field definitions:")
    let customStatements = try await db.defineTable(
        tableName: "products",
        fields: [
            ("name", "string", false),
            ("price", "float", false),
            ("description", "string", true),
            ("stock", "int", false)
        ],
        mode: .schemafull,
        execute: false
    )
    for statement in customStatements {
        print("  \(statement)")
    }
    print()

    // Example 5: Generate edge with explicit constraints
    print("5. Generate edge with explicit constraints:")
    let followsStatements = try await db.defineEdge(
        edgeName: "follows",
        from: "user",
        to: "user",
        fields: [
            ("since", "datetime", false),
            ("notificationEnabled", "bool", true)
        ],
        mode: .schemafull,
        execute: false
    )
    for statement in followsStatements {
        print("  \(statement)")
    }
    print()
}

func integrationExamples(db: SurrealDB) async throws {
    print("=== Integration Examples ===\n")

    // Example 6: Use SchemaGenerator directly
    print("6. Direct schema generation with SchemaGenerator:")
    let directStatements = try SchemaGenerator.generateTableSchema(
        for: User.self,
        mode: .schemafull,
        drop: true  // Include DROP TABLE statement
    )
    for statement in directStatements {
        print("  \(statement)")
    }
    print()

    // Example 7: Type mapping
    print("7. Swift to SurrealDB type mapping:")
    let swiftTypes = ["String", "Int", "Double", "Bool", "Date", "UUID", "Array<String>"]
    for swiftType in swiftTypes {
        let surrealType = SchemaGenerator.mapSwiftType(swiftType)
        print("  \(swiftType) -> \(surrealType)")
    }
    print()

    // Example 8: Schema introspection
    print("8. List all tables in database:")
    let tables = try await db.listTables()
    for table in tables {
        print("  - \(table)")
    }
    print()

    // Example 9: Describe table schema
    print("9. Describe Post table:")
    let postInfo = try await db.describeTable("post")
    print("  \(postInfo)")
    print()
}

func schemaManagementExample() async throws {
    // Connect to SurrealDB
    let db = try SurrealDB(url: "ws://localhost:8000/rpc")
    try await db.connect()
    try await db.signin(.root(RootAuth(username: "root", password: "root")))
    try await db.use(namespace: "test", database: "test")

    try await schemaGenerationExamples(db: db)
    try await explicitSchemaExamples(db: db)
    try await integrationExamples(db: db)

    // Clean up
    try await db.disconnect()
}

// MARK: - Run Example

// Uncomment to run:
// Task {
//     do {
//         try await schemaManagementExample()
//     } catch {
//         print("Error: \(error)")
//     }
// }
