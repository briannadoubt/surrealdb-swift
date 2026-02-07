import Foundation
@testable import SurrealDB

/// Mock transport for testing without a real SurrealDB connection.
@SurrealActor
final class MockTransport: Transport {
    var sentRequests: [JSONRPCRequest] = []
    var responseQueue: [String: JSONRPCResponse] = [:]
    var defaultResult: SurrealValue = .null
    var isConnectedInternal: Bool = false
    private let transportConfig: TransportConfig

    private var notificationContinuation: AsyncStream<LiveQueryNotification>.Continuation?
    private let notificationStream: AsyncStream<LiveQueryNotification>
    private var eventContinuation: AsyncStream<TransportConnectionEvent>.Continuation?
    private let eventStream: AsyncStream<TransportConnectionEvent>

    nonisolated init(config: TransportConfig = .default) {
        self.transportConfig = config
        var cont: AsyncStream<LiveQueryNotification>.Continuation?
        self.notificationStream = AsyncStream { continuation in
            cont = continuation
        }
        self.notificationContinuation = cont

        var events: AsyncStream<TransportConnectionEvent>.Continuation?
        self.eventStream = AsyncStream { continuation in
            events = continuation
        }
        self.eventContinuation = events
    }

    var config: TransportConfig {
        get async { transportConfig }
    }

    func connect() async throws(SurrealError) {
        isConnectedInternal = true
        eventContinuation?.yield(.connected)
    }

    func disconnect() async throws(SurrealError) {
        isConnectedInternal = false
        sentRequests.removeAll()
        responseQueue.removeAll()
        notificationContinuation?.finish()
        eventContinuation?.yield(.disconnected)
    }

    func send(_ request: JSONRPCRequest) async throws(SurrealError) -> JSONRPCResponse {
        sentRequests.append(request)

        // Return queued response if available
        if let response = responseQueue.removeValue(forKey: request.id) {
            return response
        }

        // Check if there's a wildcard response queued (id: "*")
        if let response = responseQueue["*"] {
            return JSONRPCResponse(
                jsonrpc: response.jsonrpc,
                id: request.id,
                result: response.result,
                error: response.error
            )
        }

        // Return appropriate default based on method
        let result: SurrealValue
        if request.method == "query" {
            // Query responses should be an array of result objects
            result = .array([.object(["status": .string("OK"), "result": .array([])])])
        } else {
            result = defaultResult
        }

        return JSONRPCResponse(
            jsonrpc: "2.0",
            id: request.id,
            result: result,
            error: nil
        )
    }

    var isConnected: Bool {
        get async { isConnectedInternal }
    }

    var notifications: AsyncStream<LiveQueryNotification> {
        get async { notificationStream }
    }

    var connectionEvents: AsyncStream<TransportConnectionEvent> {
        get async { eventStream }
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

    func emitConnectionEvent(_ event: TransportConnectionEvent) {
        eventContinuation?.yield(event)
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
