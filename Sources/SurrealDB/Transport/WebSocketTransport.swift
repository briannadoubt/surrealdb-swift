import Foundation
import NIOCore
import NIOPosix
import WebSocketKit

/// WebSocket-based transport for SurrealDB using WebSocketKit.
///
/// This transport maintains a persistent connection and supports live queries.
/// Supports automatic reconnection with configurable policies.
/// Uses the same pattern as Trebuchet for reliable cross-platform WebSocket support.
@SurrealActor
public final class WebSocketTransport: Transport, Sendable {
    private let url: URL
    private let transportConfig: TransportConfig

    // SwiftNIO components
    private let eventLoopGroup: EventLoopGroup
    private var webSocket: WebSocket?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Request tracking
    private var pendingRequests: [String: CheckedContinuation<JSONRPCResponse, any Error>] = [:]

    // Live query notification stream
    private var notificationContinuation: AsyncStream<LiveQueryNotification>.Continuation?
    private let notificationStream: AsyncStream<LiveQueryNotification>

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

        // Create event loop group for WebSocketKit
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        // Create the notification stream with a separate continuation
        var cont: AsyncStream<LiveQueryNotification>.Continuation?
        self.notificationStream = AsyncStream { continuation in
            cont = continuation
        }
        self.notificationContinuation = cont
    }

    deinit {
        // Note: We don't shutdown the EventLoopGroup here as it may be accessed
        // from callbacks after deinit. The OS will clean up the resources.
        // For proper cleanup, users should call disconnect() before releasing the transport.
    }

    public var config: TransportConfig {
        get async { transportConfig }
    }

    public func connect() async throws(SurrealError) {
        guard !_isConnected else {
            return // Already connected
        }

        // Reset reconnection state
        shouldReconnect = true
        reconnectionAttempts = 0

        // Build WebSocket URL
        let scheme = (url.scheme == "wss" || url.scheme == "https") ? "wss" : "ws"
        let host = url.host ?? "localhost"
        let port = url.port ?? (scheme == "wss" ? 443 : 80)
        let path = url.path
        let wsURL = "\(scheme)://\(host):\(port)\(path)"

        // Create promise to capture WebSocket instance (Trebuchet pattern)
        let promise = eventLoopGroup.next().makePromise(of: WebSocket.self)

        // Connect using WebSocketKit (same pattern as Trebuchet)
        WebSocket.connect(to: wsURL, on: eventLoopGroup) { [weak self] ws in
            guard let self = self else {
                promise.fail(SurrealError.connectionError("Transport was deallocated"))
                return
            }

            // Set up message handlers INSIDE the connect callback (key to avoiding NIOLoopBound issues)
            ws.onBinary { [weak self] _, buffer in
                guard let self = self else { return }
                let data = Data(buffer: buffer)
                Task {
                    await self.handleMessage(data: data)
                }
            }

            ws.onText { [weak self] _, text in
                guard let self = self else { return }
                guard let data = text.data(using: .utf8) else { return }
                Task {
                    await self.handleMessage(data: data)
                }
            }

            ws.onClose.whenComplete { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.handleDisconnection()
                }
            }

            // Connection successful
            promise.succeed(ws)
        }
        .whenFailure { error in
            promise.fail(error)
        }

        // Wait for connection to complete
        do {
            let ws = try await promise.futureResult.get()
            self.webSocket = ws
            self._isConnected = true
        } catch {
            throw SurrealError.connectionError("Failed to connect: \(error)")
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

        // Try to decode as live query notification (wrapped in result field)
        // Format: {"result": {"action": "...", "id": "...", "result": {...}}}
        struct NotificationWrapper: Codable {
            let result: LiveQueryNotification
        }

        if let wrapper = try? decoder.decode(NotificationWrapper.self, from: data) {
            notificationContinuation?.yield(wrapper.result)
            return
        }

        // Unknown message format - ignore
    }

    private func handleDisconnection() async {
        guard _isConnected else { return }

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
    }

    public func disconnect() async throws(SurrealError) {
        _isConnected = false
        shouldReconnect = false

        // Cancel reconnection task
        reconnectionTask?.cancel()
        reconnectionTask = nil

        // Close WebSocket
        if let ws = webSocket {
            try? await ws.close()
        }

        webSocket = nil

        // Fail all pending requests
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: SurrealError.transportClosed)
        }
        pendingRequests.removeAll()

        // Close notification stream
        notificationContinuation?.finish()
    }

    public func send(_ request: JSONRPCRequest) async throws(SurrealError) -> JSONRPCResponse {
        guard let ws = webSocket, _isConnected else {
            throw SurrealError.notConnected
        }

        // Encode request to JSON
        let data: Data
        do {
            data = try encoder.encode(request)
        } catch {
            throw SurrealError.encodingError("Failed to encode request: \(error)")
        }

        // Convert Data to ByteBuffer
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)

        // Send using WebSocketKit's send method (Trebuchet pattern)
        do {
            try await ws.send(raw: buffer.readableBytesView, opcode: .binary)
        } catch {
            throw SurrealError.connectionError("Send failed: \(error)")
        }

        // Wait for response using continuation
        do {
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests[request.id] = continuation
            }
        } catch let error as SurrealError {
            throw error
        } catch {
            throw SurrealError.connectionError("Unexpected error: \(error)")
        }
    }

    public var isConnected: Bool {
        get async { _isConnected }
    }

    public var notifications: AsyncStream<LiveQueryNotification> {
        get async { notificationStream }
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
                webSocket = nil
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
                webSocket = nil
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
