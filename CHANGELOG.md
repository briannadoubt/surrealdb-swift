# Changelog

All notable changes to the SurrealDB Swift client will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-02-02

🚀 **Major Feature Release** - Comprehensive schema management system with compile-time safety.

### Added

#### Schema Management
- **@Surreal Macro** - Automatic schema generation from Swift types using SwiftSyntax
  - Generates `id: RecordID?`, `tableName`, and `_schemaDescriptor` properties
  - Adds `SurrealModel`, `Codable`, `Sendable` conformances automatically
  - Maps Swift types to SurrealDB types at compile-time
  - Detects and processes property wrappers (`@Index`, `@Computed`, `@Relation`)
  - Custom table name support via `@Surreal(tableName: "custom")`

- **@SurrealEdge Macro** - First-class graph relationship support
  - Automatically generates edge models with `From` and `To` type aliases
  - Creates `edgeName` and edge-specific schema descriptors
  - Adds `EdgeModel`, `Codable`, `Sendable` conformances
  - Custom edge name support via `@SurrealEdge(edgeName: "custom")`

- **Fluent Builder API** - Manual schema control with method chaining
  - `TableDefinitionBuilder` - Define tables with modes, types, relations
  - `FieldDefinitionBuilder` - Define fields with types, constraints, defaults
  - `IndexDefinitionBuilder` - Define indexes (unique, fulltext, search)
  - Copy-on-write pattern for thread safety
  - Comprehensive input validation
  - SQL preview via `toSurrealQL()`

- **Comprehensive Type System** - All SurrealDB types supported
  - Primitives: string, int, float, decimal, bool, datetime, duration, uuid, bytes, null, number, any
  - Collections: array<T>, set<T>
  - Special: option<T> (nullable), record<table>, geometry<type>
  - Advanced: range, literal, regex, either
  - Nested types: array<option<int>>, array<record<users>>, etc.
  - Array length constraints: array<string, 10>

- **Schema Introspection**
  - `listTables()` - Get all table names
  - `describeTable(_:)` - Get detailed table schema
  - Database info queries via `schema.info()`
  - Dry run mode for previewing changes (`execute: false`)

- **Property Wrappers**
  - `@Index(type: .unique)` - Define field indexes
  - `@Computed` - Skip database-calculated fields
  - `@Relation` - Client-side relationship helpers

#### Developer Experience
- **Reserved Keyword Validation** - 70+ SQL keywords protected
- **Type Mapping** - Automatic Swift to SurrealDB type conversion
- **SQL Injection Warnings** - Security documentation for raw expressions
- **Integration Test Skill** - Automated testing with SurrealDB instance management

### Fixed
- TypeMapper function call bug in macro-generated code
- Nested generic type parsing (Dictionary<String, Optional<Int>>)
- Double → decimal type mapping (now Double → float, Decimal → decimal)
- Namespace handling consistency for RecordID types
- Empty field name validation edge case

### Changed
- Eliminated 242 lines of duplicate TypeMapper code
- Split large test suites for better organization
- Reduced cyclomatic complexity in type system
- Improved error messages with context

### Documentation
- **5 New DocC Articles** (2,500+ lines)
  - Schema Management overview
  - Schema Macros guide
  - Schema Builders reference
  - Schema Types documentation
  - Schema Introspection guide
- **2 Complete Examples**
  - SchemaManagementExample.swift
  - ReservedKeywordValidation.swift
- Integrated with main documentation catalog
- Professional presentation with cross-references

### Tests
- **96 New Tests** - Comprehensive schema management coverage
  - 86 TypeMapper tests (0% → 100% coverage)
  - 10 Reserved keyword validation tests
  - All integration tests passing
- **Total: 286 tests** (182 unit + 104 integration/validation)
- Zero test failures, all CI checks passing

### Performance
- Compile-time schema generation (zero runtime overhead)
- Static schema descriptors (no heap allocation)
- Copy-on-write builders for thread safety
- Efficient type mapping with cached regex

### Breaking Changes
None - This release is fully backward compatible with 0.1.0.

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
