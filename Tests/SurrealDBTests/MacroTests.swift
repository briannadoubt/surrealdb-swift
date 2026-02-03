import Foundation
@testable import SurrealDB
import Testing

// Module-level test models for macro tests (macros cannot be applied to local types)
// Using "Macro" prefix to avoid naming conflicts with existing test models

@Surreal
struct MacroTestUser {
    var name: String
    var email: String
}

@Surreal(tableName: "custom_users")
struct MacroTestCustomUser {
    var username: String
}

@Surreal
struct MacroTestBlogPost {
    var title: String
}

@Surreal
struct MacroTestArticle {
    var title: String
    var content: String
    var views: Int
}

@SurrealEdge(from: MacroTestUser.self, to: MacroTestUser.self)
struct MacroTestFollows {
    var createdAt: Date
}

@SurrealEdge(from: MacroTestUser.self, to: MacroTestBlogPost.self, edgeName: "authored")
struct MacroTestAuthored {
    var role: String
}

@Suite("Macro Expansion Tests")
struct MacroTests {
    @Test("@Surreal macro generates correct table name")
    func testSurrealMacroTableName() {
        #expect(MacroTestUser.tableName == "macrotestuser")
    }

    @Test("@Surreal macro generates custom table name")
    func testSurrealMacroCustomTableName() {
        #expect(MacroTestCustomUser.tableName == "custom_users")
    }

    @Test("@Surreal macro adds id property if missing")
    func testSurrealMacroAddsId() {
        var post = MacroTestBlogPost(title: "Test")
        #expect(post.id == nil)

        // Verify we can set the id
        post.id = try? RecordID(table: "post", id: "123")
        #expect(post.id != nil)
    }

    @Test("@Surreal macro generates schema descriptor")
    func testSurrealMacroSchemaDescriptor() {
        let schema = MacroTestArticle._schemaDescriptor
        #expect(schema.tableName == "macrotestarticle")
        #expect(schema.fields.count >= 3) // At least title, content, views
        #expect(!schema.isEdge)
    }

    @Test("@SurrealEdge macro generates edge name")
    func testSurrealEdgeMacroEdgeName() {
        #expect(MacroTestFollows.edgeName == "macrotestfollows")
    }

    @Test("@SurrealEdge macro generates custom edge name")
    func testSurrealEdgeMacroCustomEdgeName() {
        #expect(MacroTestAuthored.edgeName == "authored")
    }

    @Test("@SurrealEdge macro marks schema as edge")
    func testSurrealEdgeMacroSchemaIsEdge() {
        let schema = MacroTestFollows._schemaDescriptor
        #expect(schema.isEdge)
        #expect(schema.edgeFrom == "macrotestuser")
        #expect(schema.edgeTo == "macrotestuser")
    }
}
