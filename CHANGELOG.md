# Changelog

All notable changes to the SurrealDB Swift client will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-02-01

🎉 **Initial Release** - A native Swift client for SurrealDB, the ultimate multi-model database.

### Added

- WebSocket transport for real-time connections with automatic reconnection
- HTTP transport for stateless requests
- Type-safe query building with `QueryBuilder` and automatic parameter binding
- `ComparisonOperator` enum for type-safe WHERE clauses
- Live query support via WebSocket
- CRUD operations (create, read, update, delete)
- Authentication (signin, signup, authenticate)
- Namespace and database management
- `SurrealValue` for dynamic JSON bridging
- `RecordID` for type-safe record identifiers
- `TransportConfig` for timeout and reconnection configuration
- `ReconnectionPolicy` enum (never, constant, exponentialBackoff, alwaysReconnect)
- `SurrealValidator` for identifier validation
- `IDGenerator` for optimized ID generation
- Swift concurrency support (async/await, actors)
- Comprehensive test suite including security tests
- DocC documentation with security best practices

### Security

- **SQL Injection Prevention**: All query values use automatic parameter binding
- **Identifier Validation**: Table and field names validated to prevent injection
- **Safe User Input**: User input automatically parameterized in queries
- **Security Documentation**: Comprehensive security best practices guide
- **Vulnerability Reporting**: Clear security policy and reporting procedures

### Performance

- Optimized ID generation (compact hex representation)
- Minimal validation overhead (< 1ms per query)
- Efficient WebSocket message handling
- Connection pooling ready architecture

### Documentation

- Comprehensive README with examples
- Security best practices guide
- Vulnerability reporting policy (SECURITY.md)
- Implementation status tracking
- DocC-compatible documentation comments

---

## Links

- [Repository](https://github.com/briannadoubt/surrealdb-swift)
- [Security Policy](./SECURITY.md)
