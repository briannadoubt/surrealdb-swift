import Foundation

/// Configuration for transport behavior.
public struct TransportConfig: Sendable {
    /// Timeout for individual requests (seconds).
    public let requestTimeout: TimeInterval

    /// Timeout for connection establishment (seconds).
    public let connectionTimeout: TimeInterval

    /// Reconnection policy.
    public let reconnectionPolicy: ReconnectionPolicy

    /// Payload encoding format.
    public let payloadEncoding: PayloadEncoding

    /// Maximum HTTP connections per host for URLSession pooling.
    public let httpConnectionPoolSize: Int

    /// Optional logger for diagnostics.
    public let logger: (any SurrealLogger)?

    /// Optional metrics recorder.
    public let metrics: (any SurrealMetricsRecorder)?

    /// Default configuration.
    public static let `default` = TransportConfig()

    /// Creates a transport configuration.
    ///
    /// - Parameters:
    ///   - requestTimeout: Timeout for individual requests in seconds (default: 30.0)
    ///   - connectionTimeout: Timeout for connection establishment in seconds (default: 10.0)
    ///   - reconnectionPolicy: Policy for automatic reconnection (default: exponential backoff)
    ///   - payloadEncoding: Payload encoding format (default: `.json`)
    ///   - httpConnectionPoolSize: Maximum HTTP connections per host (default: 8)
    ///   - logger: Optional logger for diagnostics
    ///   - metrics: Optional metrics recorder
    public init(
        requestTimeout: TimeInterval = 30.0,
        connectionTimeout: TimeInterval = 10.0,
        reconnectionPolicy: ReconnectionPolicy = .exponentialBackoff(),
        payloadEncoding: PayloadEncoding = .json,
        httpConnectionPoolSize: Int = 8,
        logger: (any SurrealLogger)? = nil,
        metrics: (any SurrealMetricsRecorder)? = nil
    ) {
        self.requestTimeout = requestTimeout
        self.connectionTimeout = connectionTimeout
        self.reconnectionPolicy = reconnectionPolicy
        self.payloadEncoding = payloadEncoding
        self.httpConnectionPoolSize = max(1, httpConnectionPoolSize)
        self.logger = logger
        self.metrics = metrics
    }
}

/// Defines reconnection behavior on connection loss.
public enum ReconnectionPolicy: Sendable, Equatable {
    /// No automatic reconnection.
    case never

    /// Reconnect with constant delay between attempts.
    ///
    /// - Parameters:
    ///   - delay: Fixed delay between reconnection attempts in seconds
    ///   - maxAttempts: Maximum number of reconnection attempts
    case constant(delay: TimeInterval, maxAttempts: Int)

    /// Reconnect with exponential backoff.
    ///
    /// Delays start at `initialDelay` and multiply by `multiplier` after each failed attempt,
    /// up to `maxDelay`. Stops after `maxAttempts` failures.
    ///
    /// - Parameters:
    ///   - initialDelay: Initial delay before first reconnection attempt (default: 1.0s)
    ///   - maxDelay: Maximum delay between attempts (default: 60.0s)
    ///   - multiplier: Multiplier for exponential backoff (default: 2.0)
    ///   - maxAttempts: Maximum number of reconnection attempts (default: 10)
    case exponentialBackoff(
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0,
        maxAttempts: Int = 10
    )

    /// Reconnect indefinitely with exponential backoff.
    ///
    /// Same as `exponentialBackoff` but never stops trying to reconnect.
    ///
    /// - Parameters:
    ///   - initialDelay: Initial delay before first reconnection attempt (default: 1.0s)
    ///   - maxDelay: Maximum delay between attempts (default: 60.0s)
    ///   - multiplier: Multiplier for exponential backoff (default: 2.0)
    case alwaysReconnect(
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0
    )
}
