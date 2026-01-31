/// A native Swift client for SurrealDB.
///
/// SurrealDB is a high-performance database that combines the best of SQL and NoSQL,
/// providing a flexible schema, real-time queries, and graph relations.
///
/// This library provides a native Swift implementation with support for:
/// - WebSocket and HTTP transports
/// - Type-safe operations with Codable
/// - Real-time live queries
/// - Full SurrealQL query support
/// - Fluent query builder API
///
/// ## Getting Started
///
/// ```swift
/// import SurrealDB
///
/// // Create and connect
/// let db = try SurrealDB(url: "ws://localhost:8000/rpc")
/// try await db.connect()
///
/// // Authenticate
/// try await db.signin(.root(RootAuth(username: "root", password: "root")))
/// try await db.use(namespace: "test", database: "test")
///
/// // Perform operations
/// let users: [User] = try await db.select("users")
/// let newUser: User = try await db.create("users", data: user)
/// ```
///
/// ## Topics
///
/// ### Client
/// - ``SurrealDB``
///
/// ### Authentication
/// - ``Credentials``
/// - ``RootAuth``
/// - ``NamespaceAuth``
/// - ``DatabaseAuth``
/// - ``RecordAccessAuth``
///
/// ### Data Types
/// - ``SurrealValue``
/// - ``RecordID``
/// - ``LiveQueryNotification``
/// - ``LiveQueryAction``
/// - ``JSONPatch``
///
/// ### Query Building
/// - ``QueryBuilder``
///
/// ### Errors
/// - ``SurrealError``
@_exported import struct Foundation.Data
@_exported import struct Foundation.URL
@_exported import struct Foundation.UUID
