import Foundation

// MARK: - Logging

/// Log levels for SurrealDB client diagnostics.
public enum SurrealLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// A pluggable logger for SurrealDB operations.
public protocol SurrealLogger: Sendable {
    func log(level: SurrealLogLevel, message: String, metadata: [String: String])
}

/// Default no-op logger.
public struct NoOpLogger: SurrealLogger {
    public init() {}

    public func log(level: SurrealLogLevel, message: String, metadata: [String: String]) {}
}

// MARK: - Metrics

/// Metric names emitted by SurrealDB transports/client.
public enum SurrealMetric: String, Sendable {
    case requestCount = "request_count"
    case requestDurationMs = "request_duration_ms"
    case requestFailures = "request_failures"
    case reconnectAttempts = "reconnect_attempts"
    case reconnectSuccess = "reconnect_success"
}

/// A pluggable metrics sink for SurrealDB operations.
public protocol SurrealMetricsRecorder: Sendable {
    func record(metric: SurrealMetric, value: Double, tags: [String: String])
}

/// Default no-op metrics recorder.
public struct NoOpMetricsRecorder: SurrealMetricsRecorder {
    public init() {}

    public func record(metric: SurrealMetric, value: Double, tags: [String: String]) {}
}
