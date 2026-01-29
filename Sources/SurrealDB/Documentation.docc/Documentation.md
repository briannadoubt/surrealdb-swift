# ``SurrealDB``

A native Swift client for SurrealDB providing type-safe operations, real-time queries, and support for all Apple platforms.

## Overview

SurrealDB Swift is a high-performance, native Swift client for [SurrealDB](https://surrealdb.com), the ultimate multi-model database. This library provides full support for:

- **WebSocket and HTTP transports** - Choose the right transport for your use case
- **Type-safe operations** - Leverage Swift's Codable for automatic encoding/decoding
- **Real-time live queries** - Subscribe to database changes in real-time
- **Fluent query builder** - Build SurrealQL queries with a type-safe API
- **Full SurrealQL support** - Execute any SurrealQL query directly
- **Swift 6 concurrency** - Built with modern Swift concurrency from the ground up

## Supported Platforms

- macOS 15.0+
- iOS 18.0+
- tvOS 18.0+
- watchOS 11.0+
- visionOS 2.0+
- Linux (with Swift 6.0+)

## Topics

### Essentials

- <doc:GettingStarted>
- ``SurrealDB``

### Authentication

- <doc:Articles/Authentication>
- ``Credentials``
- ``RootAuth``
- ``NamespaceAuth``
- ``DatabaseAuth``
- ``RecordAccessAuth``

### Data Operations

- ``SurrealValue``
- ``RecordID``
- ``JSONPatch``

### Real-time Features

- <doc:Articles/LiveQueries>
- ``LiveQueryNotification``
- ``LiveQueryAction``

### Query Building

- <doc:Articles/QueryBuilder>
- ``QueryBuilder``

### Error Handling

- ``SurrealError``
