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

}
