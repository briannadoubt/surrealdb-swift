# Claude Development Notes

This document contains architectural notes and development guidelines for the SurrealDB Swift client.

## Architecture Overview

### Core Components

1. **SurrealDB (Actor)** - Main client providing thread-safe operations
2. **Transport (Protocol)** - Abstract WebSocket/HTTP communication
3. **SurrealValue (Enum)** - Dynamic JSON bridge for Codable types
4. **RecordID (Struct)** - Type-safe record identifiers

### Concurrency Model

- `actor SurrealDB` - Provides automatic serialization of client operations
- `@SurrealActor` - Global actor isolating transport layer
- `AsyncStream` - For live query notifications
- `CheckedContinuation` - For request/response pairing in WebSocket

### Critical Implementation Details

#### WebSocket Transport

The WebSocket transport maintains two parallel message flows:

1. **Request/Response** - JSON-RPC with continuation-based pairing
2. **Notifications** - Live query events pushed from server

Message handling:
```swift
// Try JSON-RPC response first (has id field)
if let response = decode(JSONRPCResponse), let id = response.id {
    pendingRequests[id]?.resume(returning: response)
}
// Fall back to live query notification
else if let notification = decode(LiveQueryNotification) {
    notificationContinuation.yield(notification)
}
```

#### Live Query Routing

The `SurrealDB` actor routes notifications to individual query streams:

```swift
private func routeLiveQueryNotifications() async {
    for await notification in transport.notifications {
        if let queryId = notification.id,
           let continuation = liveQueryStreams[queryId] {
            continuation.yield(notification)
        }
    }
}
```

### Type Safety Strategy

1. Generic methods accept `Encodable` for input, `Decodable` for output
2. `SurrealValue` bridges between typed Swift and JSON-RPC
3. All conversions go through `Codable` serialization

```swift
// User provides typed data
let user: User = ...

// Convert to SurrealValue
let value = try SurrealValue(from: user)

// Send as JSON-RPC parameter
let params = [value]

// Decode response back to type
let result: User = try response.decode()
```

## Development Commands

### Build

```bash
swift build
```

### Test

```bash
# Unit tests only
swift test

# With integration tests
SURREALDB_TEST=1 swift test
```

**IMPORTANT: Use Swift Testing, not XCTest**
- Use `@Test` macro instead of `func test*()` methods
- Use `#expect()` instead of `XCTAssert*()`
- Use `@Suite` for organizing tests
- Use `throws` for error testing
- No need for class inheritance or `XCTestCase`

### Documentation

```bash
# Generate DocC documentation
swift package generate-documentation --target SurrealDB

# Preview documentation
swift package --disable-sandbox preview-documentation --target SurrealDB
```

### Lint (if using SwiftLint)

```bash
swiftlint lint
```

## Testing Strategy

### Unit Tests

Use `MockTransport` for isolated testing:

```swift
@SurrealActor
final class MockTransport: Transport {
    var sentRequests: [JSONRPCRequest] = []
    var responseQueue: [String: JSONRPCResponse] = [:]

    func send(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        sentRequests.append(request)
        return responseQueue[request.id] ?? defaultResponse(for: request)
    }
}
```

### Integration Tests

Require running SurrealDB instance:

```swift
guard ProcessInfo.processInfo.environment["SURREALDB_TEST"] == "1" else {
    throw XCTSkip("Integration tests require SurrealDB")
}
```

## Known Limitations

1. **HTTP Transport**
   - No live query support
   - No variable support (let/unset)
   - Stateless (auth headers per-request)

2. **Live Query Format**
   - Notification format may vary by SurrealDB version
   - Current implementation assumes `id` field for routing
   - Needs verification against production servers

3. **Platform Support**
   - Requires Swift 6.0+ for strict concurrency
   - Minimum OS versions for async/await support

## Future Enhancements

### Post-1.0 Features

1. **CBOR Encoding**
   - Add as optional transport encoding
   - Should be pluggable via protocol

2. **Automatic Reconnection**
   - Exponential backoff strategy
   - Restore live queries after reconnect
   - Queue operations during disconnect

3. **Type-Safe Query Builder**
   - Use result builders for compile-time validation
   - Type-safe field selection
   - Phantom types for query state

4. **Connection Pooling**
   - Pool of HTTP transports
   - Load balancing
   - Health checking

5. **Observability**
   - Structured logging with OSLog
   - Metrics collection
   - Distributed tracing

### Architectural Improvements

1. **Middleware System**
   - Request/response interceptors
   - Logging, metrics, retry logic
   - Authentication token refresh

2. **Caching Layer**
   - In-memory result caching
   - Invalidation on live query notifications
   - TTL and LRU policies

3. **Offline Support**
   - Local storage for operations
   - Sync queue when reconnected
   - Conflict resolution strategies

## Debugging Tips

### Enable Logging

Add logging to transport layer:

```swift
print("→ Sending:", request)
print("← Received:", response)
```

### Inspect WebSocket Messages

Use proxy tools like Charles or Wireshark to inspect WebSocket frames.

### Test with Real Server

```bash
# Start SurrealDB with verbose logging
surreal start --user root --pass root --log trace memory
```

### Common Issues

1. **"Transport closed" errors**
   - Check WebSocket connection stability
   - Verify server is running
   - Check for network issues

2. **"Invalid response" errors**
   - Enable logging to see raw responses
   - Verify SurrealDB version compatibility
   - Check for malformed queries

3. **Live queries not working**
   - Ensure using WebSocket transport
   - Verify notification routing logic
   - Check server logs for errors

## Code Style

### Conventions

- Use `async/await` for all asynchronous operations
- Prefer `throw` over `Result` for error handling
- Document public APIs with DocC comments
- Use `Sendable` consistently for concurrency safety

### Naming

- Methods follow SurrealDB RPC names (select, create, update, etc.)
- Internal helpers prefixed with underscore if needed
- Swift naming conventions (camelCase)

### Error Handling

Always provide context in errors:

```swift
throw SurrealError.invalidResponse("Expected array, got \(value)")
```

## Release Checklist

Before releasing a new version:

1. ✅ All tests passing
2. ✅ Documentation generated and reviewed
3. ✅ README updated with new features
4. ✅ CHANGELOG updated
5. ✅ Version bumped in appropriate places
6. ✅ Integration tests passed with real SurrealDB
7. ✅ Platform testing completed
8. ✅ Example projects updated

## References

### SurrealDB Documentation

- [RPC Protocol](https://surrealdb.com/docs/surrealdb/integration/rpc)
- [JavaScript SDK](https://github.com/surrealdb/surrealdb.js)
- [SurrealQL](https://surrealdb.com/docs/surrealql)

### Swift Resources

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
- [Sendable](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
