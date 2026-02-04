import Foundation

// MARK: - Live Queries

extension SurrealDB {
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
}
