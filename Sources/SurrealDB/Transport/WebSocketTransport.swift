import Foundation

/// WebSocket-based transport for SurrealDB.
///
/// This transport maintains a persistent connection and supports live queries.
/// Supports automatic reconnection with configurable policies.
@SurrealActor
public final class WebSocketTransport: Transport, Sendable {
    private let url: URL
    private let transportConfig: TransportConfig
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
    private var reconnectionTask: Task<Void, Never>?
    private var _isConnected: Bool = false
    private var reconnectionAttempts: Int = 0
    private var shouldReconnect: Bool = true

    /// Creates a new WebSocket transport.
    ///
    /// - Parameters:
    ///   - url: The WebSocket URL of the SurrealDB server (e.g., "ws://localhost:8000/rpc").
    ///   - config: Transport configuration including timeouts and reconnection policy.
    nonisolated public init(url: URL, config: TransportConfig = .default) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if components.path.isEmpty || components.path == "/" {
            components.path = "/rpc"
        }
        self.url = components.url!
        self.transportConfig = config
        self.session = URLSession(configuration: .default)

        // Create the notification stream with a separate continuation
        var cont: AsyncStream<LiveQueryNotification>.Continuation?
        self.notificationStream = AsyncStream { continuation in
            cont = continuation
        }
        self.notificationContinuation = cont
    }

    public var config: TransportConfig {
        get async { transportConfig }
    }

    public func connect() async throws {
        guard webSocketTask == nil else {
            return // Already connected
        }

        // Reset reconnection state
        shouldReconnect = true
        reconnectionAttempts = 0

        // Create and start WebSocket connection
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        _isConnected = true

        // Start receiving messages
        receiveTask = Task { @SurrealActor in
            await self.receiveMessages()
        }
    }

    public func disconnect() async throws {
        _isConnected = false
        shouldReconnect = false

        // Cancel reconnection task
        reconnectionTask?.cancel()
        reconnectionTask = nil

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

        // Send and wait for response
        // Note: Timeout is handled by URLSession configuration
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

                // Attempt reconnection if enabled
                if shouldReconnect {
                    await attemptReconnection()
                }

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

    // MARK: - Reconnection

    private func attemptReconnection() async {
        switch transportConfig.reconnectionPolicy {
        case .never:
            return

        case .constant(let delay, let maxAttempts):
            await reconnectWithConstantDelay(delay: delay, maxAttempts: maxAttempts)

        case .exponentialBackoff(let initial, let max, let multiplier, let maxAttempts):
            await reconnectWithExponentialBackoff(
                initialDelay: initial,
                maxDelay: max,
                multiplier: multiplier,
                maxAttempts: maxAttempts
            )

        case .alwaysReconnect(let initial, let max, let multiplier):
            await reconnectWithExponentialBackoff(
                initialDelay: initial,
                maxDelay: max,
                multiplier: multiplier,
                maxAttempts: nil
            )
        }
    }

    private func reconnectWithConstantDelay(delay: TimeInterval, maxAttempts: Int) async {
        for attempt in 1...maxAttempts {
            guard shouldReconnect else { return }

            reconnectionAttempts = attempt

            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard shouldReconnect else { return }

                // Reset state
                webSocketTask = nil
                try await connect()

                // Success - reset attempts
                reconnectionAttempts = 0
                return
            } catch {
                if attempt == maxAttempts {
                    return
                }
            }
        }
    }

    private func reconnectWithExponentialBackoff(
        initialDelay: TimeInterval,
        maxDelay: TimeInterval,
        multiplier: Double,
        maxAttempts: Int?
    ) async {
        reconnectionAttempts = 0
        var currentDelay = initialDelay

        while shouldReconnect {
            guard maxAttempts == nil || reconnectionAttempts < maxAttempts! else {
                return
            }

            reconnectionAttempts += 1

            do {
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                guard shouldReconnect else { return }

                // Reset state
                webSocketTask = nil
                try await connect()

                // Success - reset attempts
                reconnectionAttempts = 0
                return
            } catch {
                // Exponential backoff
                currentDelay = min(currentDelay * multiplier, maxDelay)

                if let max = maxAttempts, reconnectionAttempts >= max {
                    return
                }
            }
        }
    }

}
