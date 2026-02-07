import Foundation

/// Lifecycle events emitted by transports.
public enum TransportConnectionEvent: Sendable {
    case connected
    case disconnected
    case reconnected(attempt: Int)
}

/// A transport mechanism for communicating with SurrealDB.
///
/// Implementations include WebSocket and HTTP transports.
@SurrealActor
public protocol Transport: Sendable {
    /// Configuration for this transport.
    var config: TransportConfig { get async }

    /// Establishes a connection to the database.
    func connect() async throws(SurrealError)

    /// Closes the connection to the database.
    func disconnect() async throws(SurrealError)

    /// Sends a JSON-RPC request and returns the response.
    func send(_ request: JSONRPCRequest) async throws(SurrealError) -> JSONRPCResponse

    /// Returns whether the transport is currently connected.
    var isConnected: Bool { get async }

    /// A stream of live query notifications.
    ///
    /// For transports that don't support live queries (like HTTP), this returns an empty stream.
    var notifications: AsyncStream<LiveQueryNotification> { get async }

    /// A stream of connection lifecycle events.
    var connectionEvents: AsyncStream<TransportConnectionEvent> { get async }
}
