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
4. Set up development tools (see below)

### Development Setup

#### Install SwiftLint

SwiftLint is required for code quality checks:

```bash
brew install swiftlint
```

#### Install Pre-Commit Hook

To automatically run SwiftLint before each commit:

```bash
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

The hook will:
- Run SwiftLint on staged Swift files
- Prevent commits if violations are found
- Can be bypassed with `git commit --no-verify` (not recommended)

#### Run SwiftLint Manually

```bash
# Check for violations
swiftlint lint

# Auto-fix violations (where possible)
swiftlint lint --fix

# Check with strict mode (warnings treated as errors)
swiftlint lint --strict
```

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
