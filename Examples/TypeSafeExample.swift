import Foundation
import SurrealDB

// This example demonstrates the type-safe API with graph relationships

@main
struct TypeSafeExample {
    static func main() async throws {
        print("=== Type-Safe SurrealDB Example ===\n")

        // Connect
        let db = try SurrealDB(url: "ws://localhost:8000/rpc")
        try await db.connect()
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        // Define models
        struct User: SurrealModel {
            @ID var id: RecordID?
            var name: String
            var email: String
            var age: Int
            var verified: Bool

            @Relation(edge: Authored.self)
            var posts: [Post]

            @Relation(edge: Follows.self, direction: .out)
            var following: [User]

            @Computed("count(->authored->post)")
            var postCount: Int?
        }

        struct Post: SurrealModel {
            @ID var id: RecordID?
            var title: String
            var content: String
            var publishedAt: Date

            @Relation(edge: Authored.self, direction: .in)
            var author: User
        }

        struct Authored: EdgeModel {
            typealias From = User
            typealias To = Post
            var publishedAt: Date
            var featured: Bool
        }

        struct Follows: EdgeModel {
            typealias From = User
            typealias To = User
            var since: Date
        }

        print("1. Creating users...")

        // Create users
        let alice = User(
            id: nil,
            name: "Alice",
            email: "alice@example.com",
            age: 28,
            verified: true
        )

        let bob = User(
            id: nil,
            name: "Bob",
            email: "bob@example.com",
            age: 32,
            verified: true
        )

        let charlie = User(
            id: nil,
            name: "Charlie",
            email: "charlie@example.com",
            age: 17,
            verified: false
        )

        let savedAlice: User = try await db.create("users:alice", data: alice)
        let savedBob: User = try await db.create("users:bob", data: bob)
        let savedCharlie: User = try await db.create("users:charlie", data: charlie)

        print("   ✅ Created 3 users")

        print("\n2. Type-safe query - Adults only...")

        // Type-safe query with KeyPath predicates
        let adults = try await db.query(User.self)
            .where(\User.age >= 18)
            .where(\User.verified == true)
            .orderBy(\User.name, ascending: true)
            .fetch()

        print("   Found \(adults.count) adults:")
        for user in adults {
            print("   - \(user.name), age \(user.age)")
        }

        print("\n3. Creating posts...")

        // Create posts
        let post1 = Post(
            id: nil,
            title: "Introduction to SurrealDB",
            content: "SurrealDB is a powerful database...",
            publishedAt: Date()
        )

        let post2 = Post(
            id: nil,
            title: "Swift Concurrency",
            content: "Modern Swift uses async/await...",
            publishedAt: Date()
        )

        let savedPost1: Post = try await db.create("posts:post1", data: post1)
        let savedPost2: Post = try await db.create("posts:post2", data: post2)

        print("   ✅ Created 2 posts")

        print("\n4. Creating relationships...")

        // Create author relationships
        try await savedAlice.relate(
            to: savedPost1,
            via: Authored(publishedAt: Date(), featured: true),
            using: db
        )

        try await savedBob.relate(
            to: savedPost2,
            via: Authored(publishedAt: Date(), featured: false),
            using: db
        )

        // Create follow relationship
        try await savedAlice.relate(
            to: savedBob,
            via: Follows(since: Date()),
            using: db
        )

        print("   ✅ Alice authored post1")
        print("   ✅ Bob authored post2")
        print("   ✅ Alice follows Bob")

        print("\n5. Loading relationships...")

        // Load posts for a user
        let alicePosts = try await savedAlice.load(\.posts, using: db)
        print("   Alice's posts:")
        for post in alicePosts {
            print("   - \(post.title)")
        }

        print("\n6. Complex query with ordering...")

        // Query recent posts
        let recentPosts = try await db.query(Post.self)
            .select(\Post.title, \Post.publishedAt)
            .orderBy(\Post.publishedAt, ascending: false)
            .limit(10)
            .fetch()

        print("   Recent posts:")
        for post in recentPosts {
            print("   - \(post.title)")
        }

        print("\n7. Graph traversal query...")

        // Raw query for graph traversal
        guard let aliceId = savedAlice.id else {
            throw SurrealError.invalidRecordID("Alice has no ID")
        }

        let query = """
        SELECT * FROM \(aliceId.toString())
            ->follows->users
            ->authored->posts
        """

        let results = try await db.query(query)
        print("   Posts by people Alice follows: \(results.count) results")

        print("\n8. Cleanup...")
        try await db.delete("users")
        try await db.delete("posts")
        print("   ✅ Cleaned up test data")

        try await db.disconnect()
        print("\n✅ Done!")
    }
}

// MARK: - Extension for relate functionality

extension SurrealModel {
    func relate<Edge: EdgeModel, Target: SurrealModel>(
        to target: Target,
        via edge: Edge,
        using db: SurrealDB
    ) async throws -> Edge where Edge.From == Self, Edge.To == Target {
        guard let fromId = self.id, let toId = target.id else {
            throw SurrealError.invalidRecordID("Both models must have IDs")
        }

        return try await db.relate(
            from: fromId,
            via: Edge.edgeName,
            to: toId,
            data: edge
        )
    }

    func load<Edge: EdgeModel>(
        _ keyPath: KeyPath<Self, Relation<Edge.To, Edge>>,
        using db: SurrealDB
    ) async throws -> [Edge.To] where Edge.From == Self {
        guard let id = self.id else {
            throw SurrealError.invalidRecordID("Model must have an ID")
        }

        let relation = self[keyPath: keyPath]
        let direction = relation.direction == .out ? "->" : "<-"
        let edgeName = Edge.edgeName

        let query = """
        SELECT * FROM \(id.toString())\(direction)\(edgeName)\(direction)\(Edge.To.tableName)
        """

        let results = try await db.query(query)
        guard let firstResult = results.first else {
            return []
        }

        // Handle result structure
        if case .object(let obj) = firstResult, let result = obj["result"] {
            if case .array(let array) = result {
                return try array.map { try $0.decode() }
            }
        }

        if case .array(let array) = firstResult {
            return try array.map { try $0.decode() }
        }

        return try [firstResult.decode()]
    }
}
