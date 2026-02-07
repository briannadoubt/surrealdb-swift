# Deferred Backlog Plan

This document tracks the backlog items that were previously deferred and their current status.

## Scope

Originally deferred items:
1. CBOR encoding
2. Automatic reconnection
3. Type-safe query builder (result builder)
4. Connection pooling
5. Logging/metrics

## Current Status

### 1) CBOR encoding
Status: Implemented

Implemented in this pass:
- Added `PayloadEncoding` (`.json`, `.cbor`)
- Added `PayloadCodec` with JSON and CBOR support
- Wired into `HTTPTransport` and `WebSocketTransport`
- Added codec tests in `DeferredBacklogTests`

Follow-ups:
- Add integration tests against a live SurrealDB endpoint configured for CBOR
- Consider swapping `MiniCBOR` with a fully featured CBOR library if advanced CBOR tags are needed

### 2) Automatic reconnection
Status: Implemented and improved

Implemented in this pass:
- Added `TransportConnectionEvent` stream
- WebSocket transport now emits reconnect lifecycle events
- `SurrealDB` listens for reconnect events and restores auth + namespace/database session

Follow-ups:
- Add a deterministic integration test for socket drop + reconnect with live server
- Optionally add jitter to reconnect backoff

### 3) Type-safe query builder result builder
Status: Implemented

Implemented in this pass:
- Added `@QueryDSLBuilder`
- Added components: `Select`, `Where`, `OrderBy`, `Limit`, `Offset`
- Added `SurrealDB.query(_: @QueryDSLBuilder)` overload
- Added DSL query test in `DeferredBacklogTests`

Follow-ups:
- Add first-class graph traversal clauses and relation include semantics in DSL
- Add richer compile-time validation for invalid clause ordering

### 4) Connection pooling
Status: Implemented

Implemented in this pass:
- Added `httpConnectionPoolSize` to `TransportConfig`
- Wired to `URLSessionConfiguration.httpMaximumConnectionsPerHost`

Follow-ups:
- Add stress/perf benchmark coverage to tune defaults by platform

### 5) Logging and metrics
Status: Implemented

Implemented in this pass:
- Added `SurrealLogger` and `SurrealMetricsRecorder` interfaces
- Added no-op defaults
- Wired request/reconnect metrics and selected logs in HTTP/WebSocket transports

Follow-ups:
- Publish adapters for `swift-log` and common telemetry backends
- Expand metrics/tags for cache and live query routing

## Trebuchet App Wiring Status

Status: Partially implemented

Implemented:
- Added first-class app contract: `SurrealDBService` in library sources
- Added `LocalSurrealDBService` adapter over `SurrealDB`
- Added practical integration guide and example for Trebuchet wrappers

Remaining:
- Provide an optional `SurrealDBTrebuchet` companion target once Trebuchet dependency/version is finalized
- Add end-to-end distributed tests in an app repo that includes Trebuchet runtime

## Rollout Notes

- Backward compatible defaults are preserved (`.json`, no-op observability, unchanged integration test gating).
- Integration tests remain local-only (`SURREALDB_TEST=1`) by design.
