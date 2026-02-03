import Foundation

// MARK: - Schema Management Extension

extension SurrealDB {
    // MARK: - Table Schema Definition

    /// Generates and optionally executes DEFINE statements for a SurrealModel.
    ///
    /// This method analyzes the model type and generates appropriate schema
    /// definitions including the table and all its fields (in schemafull mode).
    ///
    /// Example:
    /// ```swift
    /// struct User: SurrealModel {
    ///     var id: RecordID?
    ///     var name: String
    ///     var email: String
    ///     var age: Int
    /// }
    ///
    /// // Dry run - just get the statements
    /// let statements = try await db.defineTable(for: User.self, execute: false)
    /// print(statements.joined(separator: "\n"))
    ///
    /// // Execute the schema
    /// try await db.defineTable(for: User.self, mode: .schemafull, execute: true)
    /// ```
    ///
    /// - Parameters:
    ///   - type: The SurrealModel type to generate schema for.
    ///   - mode: The schema mode (default: .schemafull).
    ///   - drop: If true, drops the table before creating it (default: false).
    ///   - execute: If true, executes the statements; if false, just returns them (default: true).
    /// - Returns: Array of generated SurrealQL statements.
    /// - Throws: ``SurrealError`` if schema generation or execution fails.
    public func defineTable<T: SurrealModel>(
        for type: T.Type,
        mode: SchemaMode = .schemafull,
        drop: Bool = false,
        execute: Bool = true
    ) async throws(SurrealError) -> [String] {
        // Generate schema statements
        let statements = try SchemaGenerator.generateTableSchema(
            for: type,
            mode: mode,
            drop: drop
        )

        // Execute if requested
        if execute {
            try await executeSchemaStatements(statements)
        }

        return statements
    }

    /// Generates and optionally executes schema for a model with explicit field definitions.
    ///
    /// This method is useful when you want to define schema without relying on
    /// reflection or macros, providing explicit control over the schema definition.
    ///
    /// Example:
    /// ```swift
    /// let statements = try await db.defineTable(
    ///     tableName: "users",
    ///     fields: [
    ///         .init(name: "name", type: "string", optional: false),
    ///         .init(name: "email", type: "string", optional: false),
    ///         .init(name: "age", type: "int", optional: true)
    ///     ],
    ///     mode: .schemafull,
    ///     execute: true
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - tableName: The name of the table.
    ///   - fields: Array of field definitions.
    ///   - mode: The schema mode (default: .schemafull).
    ///   - drop: If true, drops the table before creating it (default: false).
    ///   - execute: If true, executes the statements (default: true).
    /// - Returns: Array of generated SurrealQL statements.
    /// - Throws: ``SurrealError`` if schema generation or execution fails.
    public func defineTable(
        tableName: StaticString,
        fields: [SchemaGenerator.FieldDefinition],
        mode: SchemaMode = .schemafull,
        drop: Bool = false,
        execute: Bool = true
    ) async throws(SurrealError) -> [String] {
        // Convert StaticString to String
        let tableNameStr = String(describing: tableName)

        // Validate table name
        try SurrealValidator.validateTableName(tableNameStr)

        // Validate field names
        for field in fields {
            try SurrealValidator.validateFieldName(field.name)
        }

        // Generate schema statements
        let statements = SchemaGenerator.generateSchema(
            tableName: tableNameStr,
            fields: fields,
            mode: mode,
            drop: drop
        )

        // Execute if requested
        if execute {
            try await executeSchemaStatements(statements)
        }

        return statements
    }

    // MARK: - Edge Schema Definition

    /// Generates and optionally executes DEFINE statements for an EdgeModel.
    ///
    /// Edge models represent relationships in SurrealDB's graph database.
    /// This method generates schema with proper IN/OUT constraints based on
    /// the edge's From and To types.
    ///
    /// Example:
    /// ```swift
    /// struct Friendship: EdgeModel {
    ///     typealias From = User
    ///     typealias To = User
    ///     var since: Date
    /// }
    ///
    /// // Generate and execute edge schema
    /// try await db.defineEdge(for: Friendship.self, mode: .schemafull)
    ///
    /// // Dry run to see statements
    /// let statements = try await db.defineEdge(for: Friendship.self, execute: false)
    /// ```
    ///
    /// - Parameters:
    ///   - type: The EdgeModel type to generate schema for.
    ///   - mode: The schema mode (default: .schemafull).
    ///   - drop: If true, drops the table before creating it (default: false).
    ///   - execute: If true, executes the statements; if false, just returns them (default: true).
    /// - Returns: Array of generated SurrealQL statements.
    /// - Throws: ``SurrealError`` if schema generation or execution fails.
    public func defineEdge<T: EdgeModel>(
        for type: T.Type,
        mode: SchemaMode = .schemafull,
        drop: Bool = false,
        execute: Bool = true
    ) async throws(SurrealError) -> [String] {
        // Generate edge schema statements
        let statements = try SchemaGenerator.generateEdgeSchema(
            for: type,
            mode: mode,
            drop: drop
        )

        // Execute if requested
        if execute {
            try await executeSchemaStatements(statements)
        }

        return statements
    }

    /// Generates and optionally executes schema for an edge with explicit constraints.
    ///
    /// This method is useful when you want to define edge schema without relying on
    /// EdgeModel types, providing explicit control over the relationship.
    ///
    /// Example:
    /// ```swift
    /// let statements = try await db.defineEdge(
    ///     edgeName: "follows",
    ///     from: "user",
    ///     to: "user",
    ///     fields: [
    ///         .init(name: "since", type: "datetime", optional: false)
    ///     ],
    ///     mode: .schemafull,
    ///     execute: true
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - edgeName: The name of the edge table.
    ///   - from: The source table name.
    ///   - to: The target table name.
    ///   - fields: Array of field definitions for edge properties.
    ///   - mode: The schema mode (default: .schemafull).
    ///   - drop: If true, drops the table before creating it (default: false).
    ///   - execute: If true, executes the statements (default: true).
    /// - Returns: Array of generated SurrealQL statements.
    /// - Throws: ``SurrealError`` if schema generation or execution fails.
    public func defineEdge(
        edgeName: StaticString,
        from fromTable: StaticString,
        to toTable: StaticString,
        fields: [SchemaGenerator.FieldDefinition] = [],
        mode: SchemaMode = .schemafull,
        drop: Bool = false,
        execute: Bool = true
    ) async throws(SurrealError) -> [String] {
        // Convert StaticStrings to Strings
        let edgeNameStr = String(describing: edgeName)
        let fromTableStr = String(describing: fromTable)
        let toTableStr = String(describing: toTable)

        // Validate names
        try SurrealValidator.validateTableName(edgeNameStr)
        try SurrealValidator.validateTableName(fromTableStr)
        try SurrealValidator.validateTableName(toTableStr)

        var statements: [String] = []

        // Add drop statement if requested
        if drop {
            statements.append("REMOVE TABLE IF EXISTS \(edgeNameStr);")
        }

        // Define the edge table
        statements.append("""
        DEFINE TABLE \(edgeNameStr) \(mode.toSurrealQL()) TYPE RELATION \
        IN \(fromTableStr) OUT \(toTableStr);
        """)

        // Add field definitions for schemafull mode
        if mode == .schemafull {
            for field in fields where field.name != "id" && field.name != "in" && field.name != "out" {
                try SurrealValidator.validateFieldName(field.name)

                var fieldDef = "DEFINE FIELD \(field.name) ON TABLE \(edgeNameStr) TYPE \(field.type)"
                if field.optional {
                    fieldDef += " FLEXIBLE"
                }
                fieldDef += ";"
                statements.append(fieldDef)
            }
        }

        // Execute if requested
        if execute {
            try await executeSchemaStatements(statements)
        }

        return statements
    }

    // MARK: - Schema Execution

    /// Executes multiple schema statements in sequence.
    ///
    /// This method executes each statement individually and collects any errors.
    /// All statements are attempted even if some fail.
    ///
    /// - Parameter statements: Array of SurrealQL statements to execute.
    /// - Throws: ``SurrealError`` if any statement fails.
    private func executeSchemaStatements(_ statements: [String]) async throws(SurrealError) {
        var errors: [String] = []

        for statement in statements where !statement.isEmpty {
            do {
                // Execute the statement
                _ = try await query(statement)
            } catch {
                errors.append("Failed to execute '\(statement)': \(error)")
            }
        }

        // If there were any errors, throw a combined error
        if !errors.isEmpty {
            throw SurrealError.invalidQuery(
                "Schema execution failed:\n" + errors.joined(separator: "\n")
            )
        }
    }

    // MARK: - Schema Introspection

    /// Retrieves information about a table's schema.
    ///
    /// This method queries SurrealDB for the table definition, including its
    /// fields, indexes, and other metadata.
    ///
    /// Example:
    /// ```swift
    /// let info = try await db.describeTable("users")
    /// print("Table: \(info)")
    /// ```
    ///
    /// - Parameter tableName: The name of the table to describe.
    /// - Returns: Table information as SurrealValue.
    /// - Throws: ``SurrealError`` if the query fails.
    public func describeTable(_ tableName: StaticString) async throws(SurrealError) -> SurrealValue {
        // Convert StaticString to String
        let tableNameStr = String(describing: tableName)

        try SurrealValidator.validateTableName(tableNameStr)

        let results = try await query("INFO FOR TABLE \(tableNameStr)")
        guard let firstResult = results.first else {
            throw SurrealError.invalidResponse("No information returned for table \(tableNameStr)")
        }

        return firstResult
    }

    /// Lists all tables in the current database.
    ///
    /// Example:
    /// ```swift
    /// let tables = try await db.listTables()
    /// for table in tables {
    ///     print("Table: \(table)")
    /// }
    /// ```
    ///
    /// - Returns: Array of table names.
    /// - Throws: ``SurrealError`` if the query fails.
    public func listTables() async throws(SurrealError) -> [String] {
        let results = try await query("INFO FOR DB")
        guard let firstResult = results.first else {
            throw SurrealError.invalidResponse("No database information returned")
        }

        // Extract table names from the result
        // The structure is: { tb: { tablename: "DEFINE TABLE ...", ... } }
        if case .object(let info) = firstResult,
           case .object(let tables) = info["tb"] {
            return Array(tables.keys)
        }

        return []
    }
}
