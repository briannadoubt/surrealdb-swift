import Foundation

/// HTTP-based transport for SurrealDB.
///
/// This transport uses HTTP POST requests to the `/rpc` endpoint.
/// It does not support live queries or variables.
@SurrealActor
public final class HTTPTransport: Transport, Sendable {
    private let url: URL
    private let session: URLSession
    private var namespace: String?
    private var database: String?
    private var authToken: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a new HTTP transport.
    ///
    /// - Parameter url: The base URL of the SurrealDB server (e.g., "http://localhost:8000").
    nonisolated public init(url: URL) {
        self.url = url
        self.session = URLSession.shared
    }

    public func connect() async throws {
        // HTTP is stateless, nothing to do
    }

    public func disconnect() async throws {
        // HTTP is stateless, nothing to do
    }

    public func send(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        let endpoint = url.appendingPathComponent("rpc")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

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
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw SurrealError.encodingError("Failed to encode request: \(error)")
        }

        // Send the request
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SurrealError.invalidResponse("Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SurrealError.connectionError("HTTP \(httpResponse.statusCode)")
        }

        // Decode the response
        do {
            return try decoder.decode(JSONRPCResponse.self, from: data)
        } catch {
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
