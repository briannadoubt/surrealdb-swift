import Foundation

/// Marks a struct as a SurrealDB model and generates schema metadata.
///
/// This macro performs the following transformations:
/// 1. Adds `id: RecordID? = nil` if not already present
/// 2. Generates `static let tableName: String` (from parameter or lowercased type name)
/// 3. Generates `static let _schemaDescriptor: SchemaDescriptor` with complete schema metadata
/// 4. Adds conformance to: `SurrealModel`, `Codable`, `Sendable`, `HasSchemaDescriptor`
///
/// ## Usage
///
/// Basic usage with automatic table name:
/// ```swift
/// @Surreal
/// struct User {
///     var name: String
///     var email: String
///     var age: Int
/// }
/// // Generates: tableName = "user"
/// ```
///
/// Custom table name:
/// ```swift
/// @Surreal(tableName: "users")
/// struct User {
///     var name: String
///     var email: String
/// }
/// ```
///
/// With property wrappers:
/// ```swift
/// @Surreal
/// struct User {
///     @Index(type: .unique)
///     var email: String
///
///     var name: String
///     var age: Int
///
///     @Computed("count(posts)")
///     var postCount: Int?
///
///     @Relation(edge: Follows.self, direction: .out)
///     var following: [User]
/// }
/// ```
///
/// ## Field Analysis
///
/// The macro automatically:
/// - Maps Swift types to SurrealDB types (String -> .string, Int -> .int, etc.)
/// - Detects Optional<T> and T? syntax for nullable fields
/// - Recognizes @Index property wrapper and extracts index type
/// - Skips @Computed fields (database-calculated, not persisted)
/// - Skips @Relation fields (graph edges, not table fields)
/// - Skips computed properties (those with getters)
///
/// ## Generated Code
///
/// For the basic User example above, the macro generates:
/// ```swift
/// extension User: SurrealModel, Codable, Sendable, HasSchemaDescriptor {
///     public var id: RecordID? = nil
///
///     public static let tableName: String = "user"
///
///     public static let _schemaDescriptor = SchemaDescriptor(
///         tableName: "user",
///         fields: [
///             FieldDescriptor(name: "name", type: .string, isOptional: false),
///             FieldDescriptor(name: "email", type: .string, isOptional: false),
///             FieldDescriptor(name: "age", type: .int, isOptional: false)
///         ]
///     )
/// }
/// ```
///
/// - Parameters:
///   - tableName: Custom table name (optional, defaults to lowercased type name)
@attached(member, names: named(id), named(tableName), named(_schemaDescriptor))
@attached(extension, conformances: SurrealModel, Codable, HasSchemaDescriptor, Sendable)
public macro Surreal(tableName: String? = nil) = #externalMacro(
    module: "SurrealDBMacros",
    type: "SurrealMacro"
)

/// Marks a struct as a SurrealDB edge model representing a relationship between two models.
///
/// This macro performs the following transformations:
/// 1. Generates `static let edgeName: String` (from parameter or lowercased type name)
/// 2. Generates `static let _schemaDescriptor: SchemaDescriptor` with edge metadata
/// 3. Adds conformance to: `EdgeModel`, `Codable`, `Sendable`, `HasSchemaDescriptor`
/// 4. Sets associated types `From` and `To` based on macro parameters
///
/// ## Usage
///
/// Basic edge with no additional properties:
/// ```swift
/// @SurrealEdge(from: User.self, to: User.self)
/// struct Follows {
///     var createdAt: Date
/// }
/// ```
///
/// Edge with custom name and properties:
/// ```swift
/// @SurrealEdge(from: User.self, to: Post.self, edgeName: "authored")
/// struct Authored {
///     var createdAt: Date
///     var role: String  // e.g., "author", "co-author"
/// }
/// ```
///
/// Edge with indexed properties:
/// ```swift
/// @SurrealEdge(from: User.self, to: Organization.self)
/// struct MemberOf {
///     @Index
///     var joinedAt: Date
///
///     var role: String
///     var permissions: [String]
/// }
/// ```
///
/// ## Generated Code
///
/// For the Follows example above, the macro generates:
/// ```swift
/// extension Follows: EdgeModel, Codable, Sendable, HasSchemaDescriptor {
///     public typealias From = User
///     public typealias To = User
///
///     public static let edgeName: String = "follows"
///
///     public static let _schemaDescriptor = SchemaDescriptor(
///         tableName: "follows",
///         fields: [
///             FieldDescriptor(name: "createdAt", type: .datetime, isOptional: false)
///         ],
///         isEdge: true,
///         edgeFrom: "user",
///         edgeTo: "user"
///     )
/// }
/// ```
///
/// ## Usage in Graph Queries
///
/// Once defined, edges can be used in graph traversals:
/// ```swift
/// // Find all users a user follows
/// let following = try await user.load(\.following, using: db)
///
/// // Create a new follow relationship
/// try await currentUser.relate(to: otherUser, via: Follows(createdAt: Date()), using: db)
/// ```
///
/// - Parameters:
///   - from: The source model type for this edge
///   - to: The target model type for this edge
///   - edgeName: Custom edge name (optional, defaults to lowercased type name)
@attached(member, names: named(From), named(To), named(edgeName), named(_schemaDescriptor))
@attached(extension, conformances: EdgeModel, Codable, HasSchemaDescriptor, Sendable)
public macro SurrealEdge(from: Any.Type, to: Any.Type, edgeName: String? = nil) = #externalMacro(
    module: "SurrealDBMacros",
    type: "SurrealEdgeMacro"
)
