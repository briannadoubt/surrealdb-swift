import Foundation
@testable import SurrealDB

/// Mock transport for testing without a real SurrealDB connection.
@SurrealActor
final class MockTransport: Transport {
    var sentRequests: [JSONRPCRequest] = []
    var responseQueue: [String: JSONRPCResponse] = [:]
    var defaultResult: SurrealValue = .null
    var _isConnected: Bool = false
    private let transportConfig: TransportConfig

    private var notificationContinuation: AsyncStream<LiveQueryNotification>.Continuation?
    private let notificationStream: AsyncStream<LiveQueryNotification>

    nonisolated init(config: TransportConfig = .default) {
        self.transportConfig = config
        var cont: AsyncStream<LiveQueryNotification>.Continuation?
        self.notificationStream = AsyncStream { continuation in
            cont = continuation
        }
        self.notificationContinuation = cont
    }

    var config: TransportConfig {
        get async { transportConfig }
    }

    func connect() async throws {
        _isConnected = true
    }

    func disconnect() async throws {
        _isConnected = false
        sentRequests.removeAll()
        responseQueue.removeAll()
        notificationContinuation?.finish()
    }

    func send(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        sentRequests.append(request)

        // Return queued response if available
        if let response = responseQueue.removeValue(forKey: request.id) {
            return response
        }

        // Return default success response
        return JSONRPCResponse(
            jsonrpc: "2.0",
            id: request.id,
            result: defaultResult,
            error: nil
        )
    }

    var isConnected: Bool {
        get async { _isConnected }
    }

    var notifications: AsyncStream<LiveQueryNotification> {
        get async { notificationStream }
    }

    // Test helpers

    func queueResponse(id: String, result: SurrealValue) {
        responseQueue[id] = JSONRPCResponse(
            jsonrpc: "2.0",
            id: id,
            result: result,
            error: nil
        )
    }

    func queueError(id: String, code: Int, message: String) {
        responseQueue[id] = JSONRPCResponse(
            jsonrpc: "2.0",
            id: id,
            result: nil,
            error: JSONRPCError(code: code, message: message, data: nil)
        )
    }

    func sendNotification(_ notification: LiveQueryNotification) {
        notificationContinuation?.yield(notification)
    }

    func lastRequest() -> JSONRPCRequest? {
        sentRequests.last
    }

    func requestCount() -> Int {
        sentRequests.count
    }

    func clearRequests() {
        sentRequests.removeAll()
    }
}
