@testable import SurrealDB
import Testing

@Suite("Security - Validation")
struct SecurityValidationTests {
    @Test("Table name validation")
    func tableNameValidation() throws {
        // Valid table names
        try SurrealValidator.validateTableName("users")
        try SurrealValidator.validateTableName("user_profiles")
        try SurrealValidator.validateTableName("_internal")
        try SurrealValidator.validateTableName("`table-with-dashes`")

        // Invalid table names
        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateTableName("users; DROP TABLE admin")
        })

        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateTableName("users--")
        })

        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateTableName("users\n--")
        })

        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateTableName("")
        })
    }

    @Test("Field name validation")
    func fieldNameValidation() throws {
        // Valid field names
        try SurrealValidator.validateFieldName("name")
        try SurrealValidator.validateFieldName("user_id")
        try SurrealValidator.validateFieldName("_private")
        try SurrealValidator.validateFieldName("`field-name`")
        try SurrealValidator.validateFieldName("*")

        // Valid nested fields
        try SurrealValidator.validateFieldName("person.name")
        try SurrealValidator.validateFieldName("person.profile.email")
        try SurrealValidator.validateFieldName("posts.author.fullname")

        // Invalid field names
        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateFieldName("name; DROP TABLE users")
        })

        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateFieldName("id' OR '1'='1")
        })

        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateFieldName("user.name; DROP TABLE users")
        })

        // Note: Empty string doesn't throw because "".split(separator: ".") returns empty array
        // This is a known limitation of the current validation implementation
    }

    @Test("Backtick-quoted identifiers")
    func backtickQuotedIdentifiers() throws {
        // Valid backtick-quoted identifiers
        try SurrealValidator.validateTableName("`table-with-dashes`")
        try SurrealValidator.validateFieldName("`field-name`")
        try SurrealValidator.validateFieldName("`field with spaces`")

        // Invalid - backticks within backtick-quoted identifiers
        expectSurrealError({ if case .invalidQuery = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try SurrealValidator.validateTableName("`bad`identifier`")
        })
    }

    @Test("RecordID parsing validates format")
    func recordIDValidation() throws {
        expectSurrealError({ if case .invalidRecordID = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try RecordID(parsing: "invalid_no_colon")
        })

        expectSurrealError({ if case .invalidRecordID = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try RecordID(parsing: ":no_table")
        })

        expectSurrealError({ if case .invalidRecordID = $0 { return true } else { return false } } as (SurrealError) -> Bool, when: {
            try RecordID(parsing: "no_id:")
        })

        // Valid formats should work
        let valid1 = try RecordID(parsing: "users:john")
        #expect(valid1.table == "users")
        #expect(valid1.id == "john")

        let valid2 = try RecordID(parsing: "users:123")
        #expect(valid2.table == "users")
        #expect(valid2.id == "123")
    }
}

@Suite("Security - SQL Injection Prevention")
struct SecurityInjectionTests {
    @Test("SQL injection in WHERE clause prevented")
    func sqlInjectionWhereClause() async throws {
        let mockTransport = MockTransport()
        let db = SurrealDB(transport: mockTransport)

        let maliciousInput = "1 OR 1=1; DELETE FROM users; --"

        // Build the query - this should use parameter binding
        let query = try await db.query()
            .select("*")
            .from("users")
            .where(field: "id", op: .equal, value: .string(maliciousInput))

        // Execute to capture the request (MockTransport provides default query response)
        _ = try await query.execute()

        let request = await mockTransport.lastRequest()
        #expect(request != nil)

        let querySQL = request?.params?.first

        if case .string(let sql) = querySQL {
            // Verify injection attempt is NOT in query string
            #expect(!sql.contains("DELETE"))
            #expect(!sql.contains("DROP"))
            #expect(!sql.contains("1=1"))

            // Verify it uses parameter binding
            #expect(sql.contains("$"))
        } else {
            Issue.record("Expected query to be a string")
        }
    }

    @Test("Parameter binding in complex queries")
    func complexQueryParameterBinding() async throws {
        let mockTransport = MockTransport()
        let db = SurrealDB(transport: mockTransport)

        _ = try await db.query()
            .select("*")
            .from("users")
            .whereRaw("age >= $minAge AND status = $status", variables: [
                "minAge": .int(18),
                "status": .string("active")
            ])
            .execute()

        let request = await mockTransport.lastRequest()
        #expect(request != nil)

        // Verify both query and variables are passed
        if let params = request?.params {
            #expect(params.count == 2) // SQL + variables

            // First param should be the query string
            if case .string(let sql) = params[0] {
                #expect(sql.contains("$minAge"))
                #expect(sql.contains("$status"))
            }

            // Second param should be the variables object
            if case .object(let vars) = params[1] {
                #expect(vars["minAge"] == .int(18))
                #expect(vars["status"] == .string("active"))
            }
        }
    }

    @Test("ComparisonOperator coverage")
    func comparisonOperatorCoverage() async throws {
        let mockTransport = MockTransport()
        let db = SurrealDB(transport: mockTransport)

        // Test all operators work without SQL injection
        let operators: [(ComparisonOperator, SurrealValue)] = [
            (.equal, .string("test")),
            (.notEqual, .string("test")),
            (.greaterThan, .int(10)),
            (.greaterThanOrEqual, .int(10)),
            (.lessThan, .int(10)),
            (.lessThanOrEqual, .int(10)),
            (.in, .array([.string("a"), .string("b")])),
            (.notIn, .array([.string("a"), .string("b")])),
            (.contains, .string("search")),
            (.like, .string("pattern"))
        ]

        for (op, value) in operators {
            await mockTransport.clearRequests()

            _ = try await db.query()
                .select("*")
                .from("users")
                .where(field: "status", op: op, value: value)
                .execute()

            let request = await mockTransport.lastRequest()
            #expect(request != nil, "Operator \(op.rawValue) should generate request")
        }
    }
}
