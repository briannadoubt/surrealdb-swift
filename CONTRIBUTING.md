# Contributing to SurrealDB Swift

Thank you for your interest in contributing to the SurrealDB Swift client! We welcome contributions from the community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
- [Release Process](#release-process)

## Code of Conduct

This project follows a standard code of conduct. Please be respectful and constructive in all interactions.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/surrealdb-swift.git
   cd surrealdb-swift
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/briannadoubt/surrealdb-swift.git
   ```

## Development Setup

### Requirements

- Swift 6.0 or later
- Xcode 16.2+ (for macOS/iOS development)
- Docker (for running integration tests)
- SwiftLint (installed automatically via pre-commit hook)

### Initial Setup

1. **Install pre-commit hooks**:
   ```bash
   git config core.hooksPath .githooks
   chmod +x .githooks/pre-commit
   ```

2. **Build the project**:
   ```bash
   swift build
   ```

3. **Run tests**:
   ```bash
   swift test
   ```

### Running Integration Tests

Integration tests require a running SurrealDB instance:

1. **Start SurrealDB with Docker**:
   ```bash
   docker compose up -d
   ```

2. **Run integration tests**:
   ```bash
   SURREALDB_TEST=1 swift test
   ```

3. **Stop SurrealDB**:
   ```bash
   docker compose down
   ```

## Making Changes

### Branching Strategy

- `main` - stable production code
- `feature/*` - new features
- `fix/*` - bug fixes
- `docs/*` - documentation updates
- `refactor/*` - code refactoring

### Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** with clear, focused commits

3. **Keep your branch updated**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

4. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

## Testing

### Test Requirements

All contributions must include appropriate tests:

- **New features**: Add unit tests and integration tests
- **Bug fixes**: Add regression tests
- **Refactoring**: Ensure existing tests pass

### Running Tests

```bash
# Unit tests only
swift test

# All tests (requires SurrealDB running)
SURREALDB_TEST=1 swift test

# Run specific test
swift test --filter TestName
```

### Test Coverage

We aim for >80% code coverage. Check coverage locally:

```bash
swift test --enable-code-coverage
```

### Writing Tests

We use **Swift Testing** (not XCTest):

```swift
import Testing
@testable import SurrealDB

@Test("Description of what this tests")
func testFeature() async throws {
    let db = try SurrealDB(url: "ws://localhost:8000/rpc")
    try await db.connect()

    let result: [User] = try await db.select("users")
    #expect(result.isEmpty)
}
```

## Code Style

### Swift Style Guide

This project follows standard Swift conventions with strict SwiftLint enforcement.

#### Key Guidelines

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 140 characters maximum
- **Naming**:
  - Types: `UpperCamelCase`
  - Functions/variables: `lowerCamelCase`
  - Constants: `lowerCamelCase`
- **Access control**: Explicit (prefer `public`, `internal`, `private`)
- **Documentation**: All public APIs must have DocC comments

#### Example

```swift
/// Creates a new record in the specified table.
///
/// - Parameters:
///   - target: The table name or record ID.
///   - data: The data for the new record.
/// - Returns: The created record.
/// - Throws: ``SurrealError`` if the operation fails.
public func create<T: Encodable, R: Decodable>(
    _ target: String,
    data: T? = nil
) async throws(SurrealError) -> R {
    // Implementation
}
```

### SwiftLint

SwiftLint runs automatically on commit via pre-commit hook. Run manually:

```bash
swiftlint lint --strict
```

Fix auto-correctable issues:

```bash
swiftlint --fix
```

### Code Organization

```
Sources/SurrealDB/
├── Client/           # Main client interface
├── Transport/        # WebSocket and HTTP transports
├── Models/           # Data models (SurrealValue, RecordID)
├── Core/             # Core utilities (errors, validation)
├── Advanced/         # Advanced features (QueryBuilder, etc.)
└── QueryBuilder/     # Fluent query API
```

## Submitting Changes

### Pull Request Process

1. **Ensure all tests pass**:
   ```bash
   swift test
   SURREALDB_TEST=1 swift test
   swiftlint lint --strict
   ```

2. **Update documentation**:
   - Add/update DocC comments for public APIs
   - Update README if needed
   - Update CHANGELOG.md

3. **Create a pull request**:
   - Use a clear, descriptive title
   - Reference any related issues
   - Describe what changed and why
   - Include test plan

### PR Title Format

```
Add feature X to improve Y
Fix bug in Z causing issue
Update documentation for feature X
Refactor component Y for better performance
```

### PR Description Template

```markdown
## Summary
Brief description of changes

## Changes
- Added X feature
- Fixed Y bug
- Updated Z documentation

## Test Plan
- [ ] Unit tests added
- [ ] Integration tests added
- [ ] Manual testing performed
- [ ] All existing tests pass

## Breaking Changes
List any breaking changes or migration requirements

## Related Issues
Closes #123
```

### Review Process

1. Automated checks must pass:
   - All tests (unit + integration)
   - SwiftLint
   - Documentation generation
   - Security scan

2. At least one maintainer approval required

3. Address review feedback

4. Squash commits if requested

## Error Handling

All throwing functions must use **typed throws**:

```swift
// ✅ Correct
public func query(_ sql: String) async throws(SurrealError) -> [SurrealValue] {
    // Implementation
}

// ❌ Incorrect
public func query(_ sql: String) async throws -> [SurrealValue] {
    // Implementation
}
```

## Documentation

### DocC Comments

All public APIs require documentation:

```swift
/// Brief one-line description.
///
/// Detailed description of what this does and when to use it.
///
/// - Parameters:
///   - param1: Description of parameter
///   - param2: Description of parameter
/// - Returns: Description of return value
/// - Throws: ``SurrealError`` with specific cases listed
///
/// Example:
/// ```swift
/// let users: [User] = try await db.select("users")
/// ```
public func method(param1: String, param2: Int) async throws(SurrealError) -> Result
```

### Building Documentation

```bash
# Generate documentation
swift package generate-documentation --target SurrealDB

# Preview documentation locally
swift package --disable-sandbox preview-documentation --target SurrealDB
```

## Release Process

Releases are managed by maintainers:

1. Update `CHANGELOG.md` with version and changes
2. Update version in documentation examples
3. Create git tag: `git tag v1.2.3`
4. Push tag: `git push origin v1.2.3`
5. GitHub Actions automatically creates release
6. Update release notes on GitHub

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for questions or ideas
- Check existing issues and PRs first

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Acknowledgments

Thank you for contributing to SurrealDB Swift! 🎉
