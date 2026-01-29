import Foundation
@testable import SurrealDB

// MARK: - Test Models

struct TestUser: SurrealModel, Equatable {
    var id: RecordID?
    var name: String
    var email: String
    var age: Int

    static var tableName: String { "users" }
}

struct TestPost: SurrealModel, Equatable {
    var id: RecordID?
    var title: String
    var content: String
    var views: Int

    static var tableName: String { "posts" }
}

struct TestComment: SurrealModel, Equatable {
    var id: RecordID?
    var text: String
    var createdAt: Date

    static var tableName: String { "comments" }
}

struct TestAuthored: EdgeModel, Codable, Sendable, Equatable {
    typealias From = TestUser
    typealias To = TestPost

    var publishedAt: Date

    static var edgeName: String { "authored" }
}

struct TestCommented: EdgeModel, Codable, Sendable, Equatable {
    typealias From = TestPost
    typealias To = TestComment

    var commentedAt: Date

    static var edgeName: String { "commented" }
}

// MARK: - Test Data Fixtures

enum TestFixtures {
    static func createUser(name: String = "Test User", email: String = "test@example.com", age: Int = 25) -> TestUser {
        TestUser(id: nil, name: name, email: email, age: age)
    }

    static func createUserWithID(id: String, name: String = "Test User") -> TestUser {
        var user = createUser(name: name)
        user.id = RecordID(table: "users", id: id)
        return user
    }

    static func createPost(title: String = "Test Post", content: String = "Test content", views: Int = 0) -> TestPost {
        TestPost(id: nil, title: title, content: content, views: views)
    }

    static func createPostWithID(id: String, title: String = "Test Post") -> TestPost {
        var post = createPost(title: title)
        post.id = RecordID(table: "posts", id: id)
        return post
    }

    static func createComment(text: String = "Test comment") -> TestComment {
        TestComment(id: nil, text: text, createdAt: Date())
    }

    static func createCommentWithID(id: String, text: String = "Test comment") -> TestComment {
        var comment = createComment(text: text)
        comment.id = RecordID(table: "comments", id: id)
        return comment
    }

    // Sample data sets
    static func createUsers(count: Int) -> [TestUser] {
        (0..<count).map { i in
            createUserWithID(id: "user\(i)", name: "User \(i)")
        }
    }

    static func createPosts(count: Int) -> [TestPost] {
        (0..<count).map { i in
            createPostWithID(id: "post\(i)", title: "Post \(i)")
        }
    }
}

// MARK: - Test Constants

enum TestConstants {
    static let testTable = "test_table"
    static let testID = "test_id_123"
    static let testRecordID = "test_table:test_id_123"
    static let testTimeout: TimeInterval = 5.0
}

// MARK: - Equatable Conformance Helpers

extension TestUser {
    static func == (lhs: TestUser, rhs: TestUser) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.email == rhs.email &&
        lhs.age == rhs.age
    }
}

extension TestPost {
    static func == (lhs: TestPost, rhs: TestPost) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.views == rhs.views
    }
}

extension TestComment {
    static func == (lhs: TestComment, rhs: TestComment) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text
    }
}
