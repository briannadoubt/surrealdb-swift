import Foundation

/// WebSocket-based transport for SurrealDB.
///
/// This transport maintains a persistent connection and supports live queries.
@SurrealActor
public final class WebSocketTransport: Transport, Sendable {
    private let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Request tracking
    private var pendingRequests: [String: CheckedContinuation<JSONRPCResponse, Error>] = [:]

    // Live query notification stream
    private var notificationContinuation: AsyncStream<LiveQueryNotification>.Continuation?
    private let notificationStream: AsyncStream<LiveQueryNotification>

    private var receiveTask: Task<Void, Never>?
    private var _isConnected: Bool = false

    /// Creates a new WebSocket transport.
    ///
    /// - Parameter url: The WebSocket URL of the SurrealDB server (e.g., "ws://localhost:8000/rpc").
    nonisolated public init(url: URL) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if components.path.isEmpty || components.path == "/" {
            components.path = "/rpc"
        }
        self.url = components.url!
        self.session = URLSession(configuration: .default)

        // Create the notification stream with a separate continuation
        var cont: AsyncStream<LiveQueryNotification>.Continuation?
        self.notificationStream = AsyncStream { continuation in
            cont = continuation
        }
        self.notificationContinuation = cont
    }

    public func connect() async throws {
        guard webSocketTask == nil else {
            return // Already connected
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        _isConnected = true

        // Start receiving messages
        receiveTask = Task {
            await receiveMessages()
        }
    }

    public func disconnect() async throws {
        _isConnected = false

        // Cancel receive task
        receiveTask?.cancel()
        receiveTask = nil

        // Close WebSocket
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        // Fail all pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: SurrealError.transportClosed)
        }
        pendingRequests.removeAll()

        // Close notification stream
        notificationContinuation?.finish()
    }

    public func send(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        guard let task = webSocketTask, _isConnected else {
            throw SurrealError.notConnected
        }

        // Encode and send the request
        let data: Data
        do {
            data = try encoder.encode(request)
        } catch {
            throw SurrealError.encodingError("Failed to encode request: \(error)")
        }

        let message = URLSessionWebSocketTask.Message.data(data)

        // Send and wait for response using continuation
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.id] = continuation

            Task {
                do {
                    try await task.send(message)
                } catch {
                    // Remove from pending and fail
                    if pendingRequests.removeValue(forKey: request.id) != nil {
                        continuation.resume(throwing: SurrealError.connectionError("Send failed: \(error)"))
                    }
                }
            }
        }
    }

    public var isConnected: Bool {
        get async { _isConnected }
    }

    public var notifications: AsyncStream<LiveQueryNotification> {
        get async { notificationStream }
    }

    // MARK: - Private

    private func receiveMessages() async {
        while let task = webSocketTask, _isConnected {
            do {
                let message = try await task.receive()

                switch message {
                case .data(let data):
                    await handleMessage(data: data)

                case .string(let text):
                    guard let data = text.data(using: .utf8) else {
                        continue
                    }
                    await handleMessage(data: data)

                @unknown default:
                    break
                }
            } catch {
                // Connection closed or error
                _isConnected = false

                // Fail all pending requests
                for (_, continuation) in pendingRequests {
                    continuation.resume(throwing: SurrealError.transportClosed)
                }
                pendingRequests.removeAll()

                break
            }
        }
    }

    private func handleMessage(data: Data) async {
        // Try to decode as JSON-RPC response first
        if let response = try? decoder.decode(JSONRPCResponse.self, from: data),
           let id = response.id,
           let continuation = pendingRequests.removeValue(forKey: id) {
            continuation.resume(returning: response)
            return
        }

        // Try to decode as live query notification
        if let notification = try? decoder.decode(LiveQueryNotification.self, from: data) {
            notificationContinuation?.yield(notification)
            return
        }

        // Unknown message format - ignore
    }
}
