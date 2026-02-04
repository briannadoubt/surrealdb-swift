import Foundation

/// The main client for interacting with SurrealDB.
///
/// This actor provides thread-safe access to all SurrealDB operations including
/// authentication, data manipulation, and live queries.
///
/// Example usage:
/// ```swift
/// let db = SurrealDB(url: "ws://localhost:8000/rpc")
/// try await db.connect()
/// try await db.signin(.root(RootAuth(username: "root", password: "root")))
/// try await db.use(namespace: "test", database: "test")
///
/// let users: [User] = try await db.select("users")
/// ```
public actor SurrealDB {
    @SurrealActor private let transport: Transport
    private var currentNamespace: String?
    private var currentDatabase: String?
    private var authToken: String?
    private var liveQueryStreams: [String: [AsyncStream<LiveQueryNotification>.Continuation]] = [:]
    private var notificationRouterTask: Task<Void, Never>?
    internal var cache: SurrealCache?
    private var liveQueryTables: [String: String] = [:]

    /// Creates a new SurrealDB client.
    ///
    /// - Parameters:
    ///   - url: The URL of the SurrealDB server.
    ///   - transportType: The transport type to use (`.websocket` or `.http`).
    ///   - config: Transport configuration including timeouts and reconnection policy.
    public init(
        url: String,
        transportType: TransportType = .websocket,
        config: TransportConfig = .default,
        cachePolicy: CachePolicy? = nil,
        cacheStorage: (any CacheStorage)? = nil
    ) throws(SurrealError) {
        guard let parsedURL = URL(string: url) else {
            throw SurrealError.connectionError("Invalid URL: \(url)")
        }

        switch transportType {
        case .websocket:
            self.transport = WebSocketTransport(url: parsedURL, config: config)
        case .http:
            self.transport = HTTPTransport(url: parsedURL, config: config)
        }

        if let cachePolicy {
            let storage = cacheStorage ?? InMemoryCacheStorage()
            self.cache = SurrealCache(storage: storage, policy: cachePolicy)
        }
    }

    /// Internal initializer for testing purposes.
    ///
    /// - Parameter transport: The transport to use for this client.
    internal init(
        transport: Transport,
        cachePolicy: CachePolicy? = nil,
        cacheStorage: (any CacheStorage)? = nil
    ) {
        self.transport = transport
        if let cachePolicy {
            let storage = cacheStorage ?? InMemoryCacheStorage()
            self.cache = SurrealCache(storage: storage, policy: cachePolicy)
        }
    }

    /// The type of transport to use.
    public enum TransportType {
        case websocket
        case http
    }

    // MARK: - Schema Management

    /// Provides access to schema management operations.
    ///
    /// Use this property to define tables, fields, and indexes using a fluent API.
    ///
    /// Example:
    /// ```swift
    /// try await db.schema
    ///     .defineTable("users")
    ///     .schemafull()
    ///     .execute()
    /// ```
    public var schema: SchemaBuilder {
        SchemaBuilder(client: self)
    }

    // MARK: - Connection Management

    /// Connects to the SurrealDB server.
    public func connect() async throws(SurrealError) {
        try await transport.connect()

        // Start routing live query notifications
        notificationRouterTask = Task {
            await routeLiveQueryNotifications()
        }
    }

    /// Disconnects from the SurrealDB server.
    public func disconnect() async throws(SurrealError) {
        notificationRouterTask?.cancel()
        notificationRouterTask = nil

        // Finish all live query streams
        for (_, continuations) in liveQueryStreams {
            for continuation in continuations {
                continuation.finish()
            }
        }
        liveQueryStreams.removeAll()

        try await transport.disconnect()
    }

    /// Gracefully closes the connection to the SurrealDB server.
    ///
    /// This method provides API parity with other SurrealDB SDKs and is functionally
    /// equivalent to ``disconnect()``.
    ///
    /// Example:
    /// ```swift
    /// try await db.close()
    /// ```
    public func close() async throws(SurrealError) {
        try await disconnect()
    }

    /// Returns whether the client is connected.
    public var isConnected: Bool {
        get async {
            await transport.isConnected
        }
    }

    /// Pings the server to check connectivity.
    public func ping() async throws(SurrealError) {
        _ = try await rpc(method: "ping", params: nil)
    }

    /// Returns the server version.
    public func version() async throws(SurrealError) -> String {
        let result = try await rpc(method: "version", params: nil)
        guard case .string(let version) = result else {
            throw SurrealError.invalidResponse("Expected string version, got \(result)")
        }
        return version
    }

    // MARK: - Namespace & Database

    /// Selects the namespace and database to use.
    ///
    /// - Parameters:
    ///   - namespace: The namespace to use.
    ///   - database: The database to use.
    public func use(namespace: String, database: String) async throws(SurrealError) {
        _ = try await rpc(method: "use", params: [.string(namespace), .string(database)])
        self.currentNamespace = namespace
        self.currentDatabase = database

        // Invalidate cache when switching namespace/database
        await cache?.invalidateAll()

        // Update HTTP transport if applicable
        if let httpTransport = transport as? HTTPTransport {
            await httpTransport.use(namespace: namespace, database: database)
        }
    }

    // MARK: - Authentication

    /// Signs in with the provided credentials.
    ///
    /// - Parameter credentials: The authentication credentials.
    /// - Returns: The authentication token.
    @discardableResult
    public func signin(_ credentials: Credentials) async throws(SurrealError) -> String {
        let params = try credentials.toSurrealValue()
        let result = try await rpc(method: "signin", params: [params])

        guard case .string(let token) = result else {
            throw SurrealError.authenticationError("Expected token string, got \(result)")
        }

        self.authToken = token

        // Update HTTP transport if applicable
        if let httpTransport = transport as? HTTPTransport {
            await httpTransport.setAuthToken(token)
        }

        return token
    }

    /// Signs up a new record access user.
    ///
    /// - Parameter credentials: The record access credentials with variables.
    /// - Returns: The authentication token.
    @discardableResult
    public func signup(_ credentials: RecordAccessAuth) async throws(SurrealError) -> String {
        let params = try SurrealValue.encode(credentials)
        let result = try await rpc(method: "signup", params: [params])

        guard case .string(let token) = result else {
            throw SurrealError.authenticationError("Expected token string, got \(result)")
        }

        self.authToken = token

        // Update HTTP transport if applicable
        if let httpTransport = transport as? HTTPTransport {
            await httpTransport.setAuthToken(token)
        }

        return token
    }

    /// Authenticates using a previously obtained token.
    ///
    /// - Parameter token: The authentication token.
    public func authenticate(token: String) async throws(SurrealError) {
        _ = try await rpc(method: "authenticate", params: [.string(token)])
        self.authToken = token

        // Update HTTP transport if applicable
        if let httpTransport = transport as? HTTPTransport {
            await httpTransport.setAuthToken(token)
        }
    }

    /// Invalidates the current authentication session.
    public func invalidate() async throws(SurrealError) {
        _ = try await rpc(method: "invalidate", params: nil)
        self.authToken = nil

        // Update HTTP transport if applicable
        if let httpTransport = transport as? HTTPTransport {
            await httpTransport.setAuthToken(nil)
        }
    }

    /// Returns information about the current authentication session.
    public func info() async throws(SurrealError) -> SurrealValue {
        try await rpc(method: "info", params: nil)
    }

    // MARK: - Variables (WebSocket only)

    /// Sets a variable for use in subsequent queries.
    ///
    /// - Parameters:
    ///   - variable: The variable name.
    ///   - value: The value to set.
    public func set(variable: String, value: SurrealValue) async throws(SurrealError) {
        guard transport is WebSocketTransport else {
            throw SurrealError.unsupportedOperation("Variables are only supported with WebSocket transport")
        }
        _ = try await rpc(method: "let", params: [.string(variable), value])
    }

    /// Unsets a variable.
    ///
    /// - Parameter variable: The variable name to unset.
    public func unset(variable: String) async throws(SurrealError) {
        guard transport is WebSocketTransport else {
            throw SurrealError.unsupportedOperation("Variables are only supported with WebSocket transport")
        }
        _ = try await rpc(method: "unset", params: [.string(variable)])
    }

    // MARK: - Data Operations

    /// Executes a custom SurrealQL query.
    ///
    /// - Parameters:
    ///   - sql: The SurrealQL query string.
    ///   - variables: Optional variables to bind in the query.
    /// - Returns: An array of results from the query.
    public func query(_ sql: String, variables: [String: SurrealValue]? = nil) async throws(SurrealError) -> [SurrealValue] {
        if let cache {
            let key = CacheKey.query(sql, variables: variables)
            if let cached = await cache.get(key) {
                guard case .array(let results) = cached else {
                    throw SurrealError.invalidResponse("Expected array of results, got \(cached)")
                }
                return results
            }
        }

        var params: [SurrealValue] = [.string(sql)]
        if let variables = variables {
            params.append(.object(variables))
        }

        let result = try await rpc(method: "query", params: params)

        guard case .array(let results) = result else {
            throw SurrealError.invalidResponse("Expected array of results, got \(result)")
        }

        if let cache {
            let tables = Self.extractTableNames(from: sql)
            let key = CacheKey.query(sql, variables: variables)
            await cache.set(key, value: result, tables: tables)
        }

        return results
    }

    /// Selects all records from a table or a specific record.
    ///
    /// - Parameter target: The table name or record ID.
    /// - Returns: The selected records.
    public func select<T: Decodable>(_ target: String) async throws(SurrealError) -> [T] {
        if let cache {
            let key = CacheKey.select(target)
            if let cached = await cache.get(key) {
                return try decodeArray(cached)
            }
        }

        let result = try await rpc(method: "select", params: [.string(target)])

        if let cache {
            let table = Self.extractTableName(from: target)
            let key = CacheKey.select(target)
            await cache.set(key, value: result, tables: [table])
        }

        return try decodeArray(result)
    }

    /// Creates a new record.
    ///
    /// - Parameters:
    ///   - target: The table name or record ID.
    ///   - data: The data for the new record (optional).
    /// - Returns: The created record.
    public func create<T: Encodable, R: Decodable>(_ target: String, data: T? = nil as T?) async throws(SurrealError) -> R {
        var params: [SurrealValue] = [.string(target)]
        if let data = data {
            params.append(try SurrealValue.encode(data))
        }

        let result = try await rpc(method: "create", params: params)

        if let cache {
            let table = Self.extractTableName(from: target)
            await cache.invalidate(table: table)
        }

        return try result.safelyDecode()
    }

    /// Inserts one or more records.
    ///
    /// - Parameters:
    ///   - target: The table name.
    ///   - data: The data to insert.
    /// - Returns: The inserted records.
    public func insert<T: Encodable, R: Decodable>(_ target: String, data: T) async throws(SurrealError) -> [R] {
        let params: [SurrealValue] = [
            .string(target),
            try SurrealValue.encode(data)
        ]

        let result = try await rpc(method: "insert", params: params)

        if let cache {
            let table = Self.extractTableName(from: target)
            await cache.invalidate(table: table)
        }

        return try decodeArray(result)
    }

    /// Updates all records in a table or a specific record.
    ///
    /// - Parameters:
    ///   - target: The table name or record ID.
    ///   - data: The data to update (optional - omit to update with empty object).
    /// - Returns: The updated record(s).
    public func update<T: Encodable, R: Decodable>(_ target: String, data: T? = nil as T?) async throws(SurrealError) -> R {
        var params: [SurrealValue] = [.string(target)]
        if let data = data {
            params.append(try SurrealValue.encode(data))
        }

        let result = try await rpc(method: "update", params: params)

        if let cache {
            let table = Self.extractTableName(from: target)
            await cache.invalidate(table: table)
        }

        return try result.safelyDecode()
    }

    /// Merges data into records.
    ///
    /// - Parameters:
    ///   - target: The table name or record ID.
    ///   - data: The data to merge.
    /// - Returns: The merged record(s).
    public func merge<T: Encodable, R: Decodable>(_ target: String, data: T) async throws(SurrealError) -> R {
        let params: [SurrealValue] = [
            .string(target),
            try SurrealValue.encode(data)
        ]

        let result = try await rpc(method: "merge", params: params)

        if let cache {
            let table = Self.extractTableName(from: target)
            await cache.invalidate(table: table)
        }

        return try result.safelyDecode()
    }

    /// Upserts (updates or inserts) records.
    ///
    /// This method creates a new record if it doesn't exist, or updates it if it does.
    /// Works with both table names (affects matching records) and specific record IDs.
    ///
    /// - Parameters:
    ///   - target: The table name or record ID.
    ///   - data: The data to upsert.
    /// - Returns: The upserted record(s).
    ///
    /// Example:
    /// ```swift
    /// // Upsert a specific record
    /// let user: User = try await db.upsert("users:john", data: User(name: "John", age: 30))
    ///
    /// // Upsert with table name
    /// let users: [User] = try await db.upsert("users", data: userData)
    /// ```
    public func upsert<T: Encodable, R: Decodable>(_ target: String, data: T) async throws(SurrealError) -> R {
        let params: [SurrealValue] = [
            .string(target),
            try SurrealValue.encode(data)
        ]

        let result = try await rpc(method: "upsert", params: params)

        if let cache {
            let table = Self.extractTableName(from: target)
            await cache.invalidate(table: table)
        }

        return try result.safelyDecode()
    }

    /// Applies JSON Patch operations to records.
    ///
    /// - Parameters:
    ///   - target: The table name or record ID.
    ///   - patches: The JSON Patch operations to apply.
    /// - Returns: The patched record(s).
    public func patch<R: Decodable>(_ target: String, patches: [JSONPatch]) async throws(SurrealError) -> R {
        let params: [SurrealValue] = [
            .string(target),
            try SurrealValue.encode(patches)
        ]

        let result = try await rpc(method: "patch", params: params)

        if let cache {
            let table = Self.extractTableName(from: target)
            await cache.invalidate(table: table)
        }

        return try result.safelyDecode()
    }

    /// Deletes all records from a table or a specific record.
    ///
    /// - Parameter target: The table name or record ID.
    public func delete(_ target: String) async throws(SurrealError) {
        _ = try await rpc(method: "delete", params: [.string(target)])

        if let cache {
            let table = Self.extractTableName(from: target)
            await cache.invalidate(table: table)
        }
    }

    // MARK: - Live Queries

    /// Creates a live query subscription.
    ///
    /// - Parameters:
    ///   - table: The table to watch.
    ///   - diff: Whether to return diffs instead of full records.
    /// - Returns: A stream of live query notifications and the query ID.
    public func live(
        _ table: String,
        diff: Bool = false
    ) async throws(SurrealError) -> (id: String, stream: AsyncStream<LiveQueryNotification>) {
        guard transport is WebSocketTransport else {
            throw SurrealError.unsupportedOperation("Live queries are only supported with WebSocket transport")
        }

        let params: [SurrealValue] = [.string(table), .bool(diff)]
        let result = try await rpc(method: "live", params: params)

        guard case .string(let queryId) = result else {
            throw SurrealError.invalidResponse("Expected query ID string, got \(result)")
        }

        liveQueryTables[queryId] = table

        let stream = AsyncStream<LiveQueryNotification> { continuation in
            if liveQueryStreams[queryId] != nil {
                liveQueryStreams[queryId]?.append(continuation)
            } else {
                liveQueryStreams[queryId] = [continuation]
            }
        }

        return (queryId, stream)
    }

    /// Kills a live query subscription.
    ///
    /// - Parameter queryId: The live query ID to kill.
    public func kill(_ queryId: String) async throws(SurrealError) {
        _ = try await rpc(method: "kill", params: [.string(queryId)])
        liveQueryTables.removeValue(forKey: queryId)

        if let continuations = liveQueryStreams.removeValue(forKey: queryId) {
            for continuation in continuations {
                continuation.finish()
            }
        }
    }

    /// Subscribes to notifications from an existing live query.
    ///
    /// This method allows subscribing to an existing live query by its ID,
    /// enabling multiple listeners for the same query. All subscriptions receive
    /// the same notifications, making it useful for broadcasting database changes
    /// to multiple parts of your application.
    ///
    /// Multiple calls to ``live(_:diff:)`` and ``subscribeLive(_:)`` with the same
    /// query ID will create independent streams that all receive notifications.
    ///
    /// - Parameter queryId: The live query UUID to subscribe to.
    /// - Returns: A stream of live query notifications.
    /// - Throws: ``SurrealError/unsupportedOperation(_:)`` if using HTTP transport.
    ///
    /// Example:
    /// ```swift
    /// // Create a live query
    /// let (queryId, stream1) = try await db.live("users")
    ///
    /// // Subscribe to the same query from another context
    /// let stream2 = try await db.subscribeLive(queryId)
    /// let stream3 = try await db.subscribeLive(queryId)
    ///
    /// // All streams receive the same notifications
    /// Task {
    ///     for await notification in stream1 {
    ///         print("Stream 1:", notification.action)
    ///     }
    /// }
    ///
    /// Task {
    ///     for await notification in stream2 {
    ///         print("Stream 2:", notification.action)
    ///     }
    /// }
    ///
    /// Task {
    ///     for await notification in stream3 {
    ///         print("Stream 3:", notification.action)
    ///     }
    /// }
    /// ```
    ///
    /// - Note: When ``kill(_:)`` is called, all streams subscribed to that query ID
    ///   will be finished and stopped receiving notifications.
    public func subscribeLive(_ queryId: String) async throws(SurrealError) -> AsyncStream<LiveQueryNotification> {
        guard transport is WebSocketTransport else {
            throw SurrealError.unsupportedOperation("Live queries are only supported with WebSocket transport")
        }

        let stream = AsyncStream<LiveQueryNotification> { continuation in
            if liveQueryStreams[queryId] != nil {
                liveQueryStreams[queryId]?.append(continuation)
            } else {
                liveQueryStreams[queryId] = [continuation]
            }
        }

        return stream
    }

    // MARK: - Internal Helpers

    internal func rpc(method: String, params: [SurrealValue]?) async throws(SurrealError) -> SurrealValue {
        let request = JSONRPCRequest(
            id: IDGenerator.generateRequestID(),
            method: method,
            params: params
        )

        let response = try await transport.send(request)

        if let error = response.error {
            throw SurrealError.rpcError(code: error.code, message: error.message, data: error.data)
        }

        guard let result = response.result else {
            throw SurrealError.invalidResponse("No result in response")
        }

        return result
    }

    /// Helper to check if using HTTP transport (for extension methods).
    internal var isHTTPTransport: Bool {
        transport is HTTPTransport
    }

    /// Helper to check if using WebSocket transport (for extension methods).
    internal var isWebSocketTransport: Bool {
        transport is WebSocketTransport
    }

    private func decodeArray<T: Decodable>(_ value: SurrealValue) throws(SurrealError) -> [T] {
        guard case .array(let array) = value else {
            // Single value - wrap in array
            let decoded: T = try value.safelyDecode()
            return [decoded]
        }

        var decoded: [T] = []
        for item in array {
            decoded.append(try item.safelyDecode())
        }
        return decoded
    }

    private func routeLiveQueryNotifications() async {
        let stream = await transport.notifications

        for await notification in stream {
            // Invalidate cache on live query notifications
            if let cache {
                let policy = await cache.cachePolicy
                if policy.invalidateOnLiveQuery,
                   notification.action != .close,
                   let queryId = notification.id,
                   let table = liveQueryTables[queryId] {
                    await cache.invalidate(table: table)
                }
            }

            // Route notification to all subscribed streams
            if let queryId = notification.id,
               let continuations = liveQueryStreams[queryId] {
                for continuation in continuations {
                    continuation.yield(notification)

                    // If it's a CLOSE notification, finish the stream
                    if notification.action == .close {
                        continuation.finish()
                    }
                }

                // Remove all continuations after CLOSE
                if notification.action == .close {
                    liveQueryStreams.removeValue(forKey: queryId)
                }
            }
        }
    }

    // MARK: - Cache Management

    /// Invalidates all entries in the cache.
    ///
    /// Call this to force all subsequent queries to fetch fresh data from the server.
    public func invalidateCache() async {
        await cache?.invalidateAll()
    }

    /// Invalidates cache entries associated with a specific table.
    ///
    /// - Parameter table: The table name whose cache entries should be invalidated.
    public func invalidateCache(table: String) async {
        await cache?.invalidate(table: table)
    }

    /// Returns statistics about the current cache state.
    ///
    /// Returns `nil` if caching is not enabled.
    public func cacheStats() async -> CacheStats? {
        await cache?.stats()
    }

    // MARK: - Table Name Extraction

    /// Extracts the table name from a target string (e.g., "users:123" -> "users").
    internal static func extractTableName(from target: String) -> String {
        if let colonIndex = target.firstIndex(of: ":") {
            return String(target[target.startIndex..<colonIndex])
        }
        return target
    }

    /// Extracts table names from a SurrealQL query string (best-effort).
    internal static func extractTableNames(from sql: String) -> Set<String> {
        var tables = Set<String>()

        // Match common SurrealQL patterns: FROM table, INTO table, UPDATE table, etc.
        let patterns = [
            "(?i)FROM\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)INTO\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)UPDATE\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)CREATE\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)DELETE\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)UPSERT\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(sql.startIndex..., in: sql)
                let matches = regex.matches(in: sql, range: range)
                for match in matches {
                    if let tableRange = Range(match.range(at: 1), in: sql) {
                        tables.insert(String(sql[tableRange]))
                    }
                }
            }
        }

        return tables
    }
}
