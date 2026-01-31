# Security Best Practices

Learn how to use the SurrealDB Swift client securely in production environments.

## Overview

The SurrealDB Swift client v2.0 provides comprehensive security features including automatic SQL injection prevention, input validation, and secure transport options.

## SQL Injection Prevention

The QueryBuilder v2.0 uses parameterized queries exclusively to prevent SQL injection attacks.

### Type-Safe Parameter Binding

All values are automatically parameterized, making user input safe to use directly:

```swift
// ✅ SAFE: Type-safe parameter binding
let adults = try await db.query()
    .select("name", "email")
    .from("users")
    .where(field: "age", op: .greaterThanOrEqual, value: .int(18))
    .fetch()

// ✅ SAFE: User input is automatically parameterized
let userInput = "admin"
let users = try await db.query()
    .select("*")
    .from("users")
    .where(field: "username", op: .equal, value: .string(userInput))
    .fetch()
```

### Complex Conditions with Explicit Variables

For complex WHERE conditions, use `whereRaw(_:variables:)` with explicit variable bindings:

```swift
// ✅ SAFE: Complex conditions with explicit variables
let results = try await db.query()
    .select("*")
    .from("users")
    .whereRaw("age >= $minAge AND verified = $verified", variables: [
        "minAge": .int(18),
        "verified": .bool(true)
    ])
    .fetch()
```

### Security by Design

The SurrealDB Swift client is designed with security as a core principle:

- **No string interpolation**: Query values are always parameterized automatically
- **Type-safe operators**: `ComparisonOperator` enum prevents operator injection
- **Validated identifiers**: All table and field names are validated before use
- **Compile-time safety**: Swift's type system catches many errors before runtime

```swift
// ✅ This is the ONLY way to build queries - secure by default
let results = try await db.query()
    .where(field: "status", op: .equal, value: .string(userInput))
    .fetch()
```

## Input Validation

All identifiers (table names, field names) are validated to ensure they follow SurrealDB naming rules.

### Identifier Rules

Valid identifiers must:
- Be alphanumeric with underscores (`a-zA-Z0-9_`)
- Start with a letter or underscore
- OR be backtick-quoted for special characters

```swift
// ✅ Valid identifiers
try db.query().from("users")
try db.query().from("user_profiles")
try db.query().from("`table-with-dashes`")

// ❌ Invalid identifiers (throws SurrealError.invalidQuery)
try db.query().from("users; DROP TABLE admin")
try db.query().from("users--")
try db.query().select("name; DROP TABLE users")
```

### Nested Field Access

Dot notation is supported for nested fields:

```swift
// ✅ Valid nested field access
try db.query().select("user.profile.name", "user.email")
```

## Token Storage

Authentication tokens are stored in memory only and are not persisted to disk.

### Production Recommendations

For production applications:

1. **Use Short-Lived Tokens**: Implement token refresh mechanisms
2. **Secure Storage**: Consider using Keychain on Apple platforms for token persistence
3. **Automatic Reauthentication**: Handle token expiry gracefully

```swift
// Example: Handle authentication errors
do {
    let results = try await db.select(from: "users")
} catch SurrealError.authenticationError {
    // Token expired - reauthenticate
    try await db.signin(username: username, password: password)
    // Retry operation
    let results = try await db.select(from: "users")
}
```

## Transport Security

Always use secure transports in production environments.

### WebSocket Security

Use `wss://` (TLS) for WebSocket connections:

```swift
// ✅ Production: Secure WebSocket
let db = try SurrealDB(url: "wss://production.example.com/rpc")

// ⚠️ Development only: Insecure WebSocket
let db = try SurrealDB(url: "ws://localhost:8000/rpc")
```

### HTTP Security

Use `https://` (TLS) for HTTP connections:

```swift
// ✅ Production: Secure HTTP
let db = try SurrealDB(url: "https://production.example.com")

// ⚠️ Development only: Insecure HTTP
let db = try SurrealDB(url: "http://localhost:8000")
```

## Timeout Configuration

Configure timeouts to prevent resource exhaustion:

```swift
let config = TransportConfig(
    requestTimeout: 30.0,      // 30 second request timeout
    connectionTimeout: 10.0,   // 10 second connection timeout
    reconnectionPolicy: .exponentialBackoff()
)

let db = try SurrealDB(url: "wss://production.example.com/rpc", config: config)
```

## Best Practices Summary

1. ✅ **Always** use type-safe parameter binding for query values
2. ✅ **Always** use secure transports (`wss://`, `https://`) in production
3. ✅ **Validate** all user input before using in queries
4. ✅ **Configure** appropriate timeouts for your use case
5. ✅ **Implement** token refresh for long-running applications
6. ✅ **Handle** authentication errors gracefully
7. ✅ **Use** environment-specific configurations (dev vs production)

## Reporting Security Issues

If you discover a security vulnerability, please report it via GitHub Security Advisories:
- [Report a vulnerability](https://github.com/briannadoubt/surrealdb-swift/security/advisories/new)

**Do not open public issues for security vulnerabilities.**

## See Also

- ``QueryBuilder``
- ``ComparisonOperator``
- ``SurrealValidator``
- ``TransportConfig``
