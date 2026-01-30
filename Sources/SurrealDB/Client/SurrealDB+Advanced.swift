import Foundation

/// Advanced SurrealDB operations.
extension SurrealDB {
    /// Creates a relationship between two records.
    ///
    /// - Parameters:
    ///   - from: The source record ID.
    ///   - via: The relationship table name.
    ///   - to: The target record ID.
    ///   - data: Optional data for the relationship record.
    /// - Returns: The created relationship record.
    public func relate<E: Encodable, R: Decodable>(
        from: RecordID,
        via: String,
        to: RecordID,
        data: E? = nil as E?
    ) async throws -> R {
        var params: [SurrealValue] = [
            .string(from.toString()),
            .string(via),
            .string(to.toString())
        ]

        if let data = data {
            params.append(try SurrealValue(from: data))
        }

        let result = try await rpc(method: "relate", params: params)
        return try result.decode()
    }

    /// Runs a custom function.
    ///
    /// - Parameters:
    ///   - function: The function name.
    ///   - version: Optional version of the function.
    ///   - arguments: Optional arguments to pass to the function.
    /// - Returns: The function result.
    public func run(
        function: String,
        version: String? = nil,
        arguments: [SurrealValue]? = nil
    ) async throws -> SurrealValue {
        var functionName = "fn::\(function)"
        if let version = version {
            functionName += ":\(version)"
        }

        var params: [SurrealValue] = [.string(functionName)]
        if let arguments = arguments {
            params.append(.array(arguments))
        }

        return try await rpc(method: "run", params: params)
    }

    /// Executes a GraphQL query.
    ///
    /// - Parameter query: The GraphQL query string.
    /// - Returns: The query result.
    public func graphql(_ query: String) async throws -> SurrealValue {
        try await rpc(method: "graphql", params: [.string(query)])
    }

    /// Exports data from the current namespace and database.
    ///
    /// This method exports the database schema and data as SurrealQL statements.
    /// The exported data can be imported using the ``import(_:)`` method.
    ///
    /// - Parameter options: Export configuration options. Defaults to exporting all data.
    /// - Returns: A string containing SurrealQL statements representing the exported data.
    /// - Throws: ``SurrealError/unsupportedOperation(_:)`` if using WebSocket transport.
    ///
    /// Example:
    /// ```swift
    /// // Export all data
    /// let backup = try await db.export()
    /// try backup.write(to: URL(fileURLWithPath: "backup.surql"))
    ///
    /// // Export specific tables
    /// let userBackup = try await db.export(options: ExportOptions(
    ///     tables: ["users", "profiles"],
    ///     functions: false
    /// ))
    /// ```
    ///
    /// - Note: Export is only supported with HTTP transport due to protocol limitations.
    public func export(options: ExportOptions = .default) async throws -> String {
        guard isHTTPTransport else {
            throw SurrealError.unsupportedOperation("Export is only supported with HTTP transport")
        }

        let result = try await rpc(method: "export", params: [try SurrealValue(from: options)])

        guard case .string(let exportData) = result else {
            throw SurrealError.invalidResponse("Expected string export data, got \(result)")
        }

        return exportData
    }

    /// Imports SurrealQL data into the current namespace and database.
    ///
    /// This method imports database schema and data from SurrealQL statements,
    /// typically from a previous export operation.
    ///
    /// - Parameter data: A string containing SurrealQL statements to import.
    /// - Throws: ``SurrealError/unsupportedOperation(_:)`` if using WebSocket transport.
    ///
    /// Example:
    /// ```swift
    /// // Import from file
    /// let sql = try String(contentsOf: URL(fileURLWithPath: "backup.surql"))
    /// try await db.import(sql)
    ///
    /// // Round-trip backup/restore
    /// let backup = try await db.export()
    /// // ... later ...
    /// try await db.import(backup)
    /// ```
    ///
    /// - Note: Import is only supported with HTTP transport due to protocol limitations.
    public func `import`(_ data: String) async throws {
        guard isHTTPTransport else {
            throw SurrealError.unsupportedOperation("Import is only supported with HTTP transport")
        }

        _ = try await rpc(method: "import", params: [.string(data)])
    }

    /// Inserts a relationship between two records.
    ///
    /// This is a specialized method for inserting relationship (edge) records,
    /// providing API parity with other SurrealDB SDKs.
    ///
    /// - Parameters:
    ///   - table: The relationship table name.
    ///   - data: The relationship data to insert.
    /// - Returns: The inserted relationship record(s).
    ///
    /// Example:
    /// ```swift
    /// struct AuthoredEdge: Codable {
    ///     let `in`: String  // from record ID
    ///     let out: String   // to record ID
    ///     let createdAt: Date
    /// }
    ///
    /// let relationship: AuthoredEdge = try await db.insertRelation(
    ///     "authored",
    ///     data: AuthoredEdge(in: "users:john", out: "posts:123", createdAt: Date())
    /// )
    /// ```
    public func insertRelation<T: Encodable, R: Decodable>(
        _ table: String,
        data: T
    ) async throws -> R {
        let params: [SurrealValue] = [
            .string(table),
            try SurrealValue(from: data)
        ]

        let result = try await rpc(method: "insert", params: params)
        return try result.decode()
    }

}
