import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP-based transport for SurrealDB.
///
/// This transport uses HTTP POST requests to the `/rpc` endpoint.
/// It does not support live queries or variables.
@SurrealActor
public final class HTTPTransport: Transport, Sendable {
    private let url: URL
    private let transportConfig: TransportConfig
    private let session: URLSession
    private var namespace: String?
    private var database: String?
    private var authToken: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var eventContinuation: AsyncStream<TransportConnectionEvent>.Continuation?
    private let eventStream: AsyncStream<TransportConnectionEvent>

    /// Creates a new HTTP transport.
    ///
    /// - Parameters:
    ///   - url: The base URL of the SurrealDB server (e.g., "http://localhost:8000").
    ///   - config: Transport configuration including timeouts.
    nonisolated public init(url: URL, config: TransportConfig = .default) {
        self.url = url
        self.transportConfig = config

        // Configure URLSession with timeouts
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.requestTimeout
        sessionConfig.timeoutIntervalForResource = config.connectionTimeout
        sessionConfig.httpMaximumConnectionsPerHost = config.httpConnectionPoolSize
        self.session = URLSession(configuration: sessionConfig)

        var continuation: AsyncStream<TransportConnectionEvent>.Continuation?
        self.eventStream = AsyncStream { cont in
            continuation = cont
        }
        self.eventContinuation = continuation
    }

    public var config: TransportConfig {
        get async { transportConfig }
    }

    public func connect() async throws(SurrealError) {
        // HTTP is stateless, nothing to do
        eventContinuation?.yield(.connected)
        transportConfig.logger?.log(level: .debug, message: "HTTP transport ready", metadata: [:])
    }

    public func disconnect() async throws(SurrealError) {
        // HTTP is stateless, nothing to do
        eventContinuation?.yield(.disconnected)
        transportConfig.logger?.log(level: .debug, message: "HTTP transport closed", metadata: [:])
    }

    // swiftlint:disable:next function_body_length
    public func send(_ request: JSONRPCRequest) async throws(SurrealError) -> JSONRPCResponse {
        let start = Date()
        let endpoint = url.appendingPathComponent("rpc")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        let contentType = transportConfig.payloadEncoding == .cbor ? "application/cbor" : "application/json"
        urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(contentType, forHTTPHeaderField: "Accept")

        // Set namespace and database headers if configured
        if let namespace = namespace {
            urlRequest.setValue(namespace, forHTTPHeaderField: "surreal-ns")
        }
        if let database = database {
            urlRequest.setValue(database, forHTTPHeaderField: "surreal-db")
        }

        // Set authorization header if we have a token
        if let authToken = authToken {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        // Encode the request
        do {
            urlRequest.httpBody = try PayloadCodec.encode(
                request,
                as: transportConfig.payloadEncoding,
                using: encoder
            )
        } catch {
            transportConfig.metrics?.record(metric: .requestFailures, value: 1, tags: ["transport": "http", "phase": "encode"])
            throw SurrealError.encodingError("Failed to encode request: \(error)")
        }

        // Send the request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            transportConfig.metrics?.record(metric: .requestFailures, value: 1, tags: ["transport": "http", "reason": "timeout"])
            throw SurrealError.timeout
        } catch {
            transportConfig.metrics?.record(metric: .requestFailures, value: 1, tags: ["transport": "http", "reason": "network"])
            throw SurrealError.connectionError("Request failed: \(error)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SurrealError.invalidResponse("Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            transportConfig.metrics?.record(
                metric: .requestFailures,
                value: 1,
                tags: ["transport": "http", "status": "\(httpResponse.statusCode)"]
            )
            throw SurrealError.connectionError("HTTP \(httpResponse.statusCode)")
        }

        // Decode the response
        do {
            let response = try PayloadCodec.decode(
                JSONRPCResponse.self,
                from: data,
                preferred: transportConfig.payloadEncoding,
                using: decoder
            )
            let ms = Date().timeIntervalSince(start) * 1000
            transportConfig.metrics?.record(metric: .requestCount, value: 1, tags: ["transport": "http", "method": request.method])
            transportConfig.metrics?.record(metric: .requestDurationMs, value: ms, tags: ["transport": "http", "method": request.method])
            return response
        } catch {
            transportConfig.metrics?.record(metric: .requestFailures, value: 1, tags: ["transport": "http", "phase": "decode"])
            throw SurrealError.invalidResponse("Failed to decode response: \(error)")
        }
    }

    public var isConnected: Bool {
        get async { true } // HTTP is always "connected"
    }

    public var notifications: AsyncStream<LiveQueryNotification> {
        get async {
            // HTTP doesn't support live queries
            AsyncStream { _ in }
        }
    }

    public var connectionEvents: AsyncStream<TransportConnectionEvent> {
        get async { eventStream }
    }

    /// Sets the namespace and database for subsequent requests.
    func use(namespace: String, database: String) {
        self.namespace = namespace
        self.database = database
    }

    /// Sets the authentication token for subsequent requests.
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
}
