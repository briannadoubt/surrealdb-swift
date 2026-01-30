# Development Documentation

This directory contains internal development documentation, design notes, and implementation guides that are not part of the public API documentation.

## Contents

### Core Documents

- **IMPLEMENTATION_SUMMARY.md** - Historical summary of the implementation phases
- **INTEGRATION_TESTS.md** - Guide for running integration tests with a live SurrealDB instance

### Design Documents (`Design/`)

- **ADVANCED_TYPE_SAFETY.md** - Design document for advanced type-safe query features
- **API_REFERENCE.md** - Comprehensive API documentation (also available in DocC)
- **TYPE_SAFETY_SUMMARY.md** - Summary of type safety and graph support implementation

## For Contributors

If you're contributing to SurrealDB Swift:

1. Start with **[CLAUDE.md](../CLAUDE.md)** (root directory) for architecture overview and coding conventions
2. Review **[Tests/README.md](../Tests/README.md)** for test requirements
3. Check **INTEGRATION_TESTS.md** for integration test setup

## Public Documentation

User-facing documentation is located in:
- **README.md** - Main project readme (root directory)
- **CHANGELOG.md** - Version history and release notes (root directory)
- **SECURITY.md** - Security policy and reporting (root directory)
- **Sources/SurrealDB/Documentation.docc/** - DocC documentation (published to GitHub Pages)

## Building Documentation

To build and preview the public documentation:

```bash
# Generate documentation
swift package generate-documentation --target SurrealDB

# Preview documentation locally
swift package --disable-sandbox preview-documentation --target SurrealDB
```

The documentation is automatically deployed to GitHub Pages on every merge to `main`.
