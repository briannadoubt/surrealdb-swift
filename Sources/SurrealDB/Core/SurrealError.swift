/// Errors that can occur when using the SurrealDB client.
public enum SurrealError: Error, Sendable, Equatable {
    /// Connection to the database failed.
    case connectionError(String)

    /// An RPC-level error occurred.
    case rpcError(code: Int, message: String, data: SurrealValue?)

    /// Authentication or authorization failed.
    case authenticationError(String)

    /// The request timed out.
    case timeout

    /// The server returned an invalid or unexpected response.
    case invalidResponse(String)

    /// The transport connection is closed.
    case transportClosed

    /// The provided record ID is invalid.
    case invalidRecordID(String)

    /// Attempted to perform an operation without an active connection.
    case notConnected

    /// Failed to encode or decode data.
    case encodingError(String)

    /// The operation is not supported by this transport.
    case unsupportedOperation(String)

    /// Invalid query syntax or identifier.
    case invalidQuery(String)
}

extension SurrealError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connectionError(let message):
            return "Connection error: \(message)"
        case .rpcError(let code, let message, let data):
            var desc = "RPC error (\(code)): \(message)"
            if let data = data {
                desc += " - \(data)"
            }
            return desc
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        case .timeout:
            return "Request timed out"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .transportClosed:
            return "Transport connection is closed"
        case .invalidRecordID(let message):
            return "Invalid record ID: \(message)"
        case .notConnected:
            return "Not connected to database"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .unsupportedOperation(let message):
            return "Unsupported operation: \(message)"
        case .invalidQuery(let message):
            return "Invalid query: \(message)"
        }
    }
}
