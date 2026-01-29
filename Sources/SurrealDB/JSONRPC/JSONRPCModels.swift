import Foundation

/// A JSON-RPC 2.0 request.
public struct JSONRPCRequest: Sendable, Codable {
    /// The JSON-RPC protocol version (always "2.0").
    public let jsonrpc: String

    /// A unique identifier for this request.
    public let id: String

    /// The RPC method name to invoke.
    public let method: String

    /// Optional parameters for the method.
    public let params: [SurrealValue]?

    public init(id: String, method: String, params: [SurrealValue]? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 response.
public struct JSONRPCResponse: Sendable, Codable {
    /// The JSON-RPC protocol version.
    public let jsonrpc: String

    /// The request ID this response corresponds to (nil for notifications).
    public let id: String?

    /// The result of a successful request.
    public let result: SurrealValue?

    /// The error details if the request failed.
    public let error: JSONRPCError?
}

/// An error in a JSON-RPC response.
public struct JSONRPCError: Sendable, Codable, Equatable {
    /// The error code.
    public let code: Int

    /// A human-readable error message.
    public let message: String

    /// Optional additional error data.
    public let data: SurrealValue?
}

/// The action type for a live query notification.
public enum LiveQueryAction: String, Sendable, Codable {
    /// A new record was created.
    case create = "CREATE"

    /// An existing record was updated.
    case update = "UPDATE"

    /// A record was deleted.
    case delete = "DELETE"

    /// The live query was closed.
    case close = "CLOSE"
}

/// A notification from a live query subscription.
public struct LiveQueryNotification: Sendable, Codable {
    /// The action that triggered this notification.
    public let action: LiveQueryAction

    /// The record data associated with this notification.
    public let result: SurrealValue

    /// The live query ID this notification belongs to.
    public let id: String?

    enum CodingKeys: String, CodingKey {
        case action, result, id
    }
}

/// Represents a JSON Patch operation.
///
/// Used for partial updates with the `patch` method.
public struct JSONPatch: Sendable, Codable {
    /// The patch operation type.
    public enum Operation: String, Sendable, Codable {
        case add, remove, replace, copy, move, test
    }

    /// The operation to perform.
    public let op: Operation

    /// The JSON pointer path to the target location.
    public let path: String

    /// The value for add, replace, and test operations.
    public let value: SurrealValue?

    /// The source path for copy and move operations.
    public let from: String?

    public init(op: Operation, path: String, value: SurrealValue? = nil, from: String? = nil) {
        self.op = op
        self.path = path
        self.value = value
        self.from = from
    }

    /// Creates an add operation.
    public static func add(path: String, value: SurrealValue) -> JSONPatch {
        JSONPatch(op: .add, path: path, value: value)
    }

    /// Creates a remove operation.
    public static func remove(path: String) -> JSONPatch {
        JSONPatch(op: .remove, path: path)
    }

    /// Creates a replace operation.
    public static func replace(path: String, value: SurrealValue) -> JSONPatch {
        JSONPatch(op: .replace, path: path, value: value)
    }
}
