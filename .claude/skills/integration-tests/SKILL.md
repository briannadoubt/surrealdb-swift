---
name: integration-tests
description: Run SurrealDB integration tests with automatic database setup and teardown. Starts SurrealDB if needed, runs tests with SURREALDB_TEST=1, and cleans up automatically.
disable-model-invocation: true
timeout: 300000
---

# Integration Tests for SurrealDB Swift Client

Run comprehensive integration tests with automatic SurrealDB instance management.

## What This Skill Does

1. **Checks if SurrealDB is running** on localhost:8000
2. **Starts SurrealDB if needed** in memory mode with root credentials
3. **Runs integration test suite** with `SURREALDB_TEST=1` environment variable
4. **Reports test results** with pass/fail summary
5. **Cleans up automatically** by stopping SurrealDB if we started it

## Requirements

- **SurrealDB installed**: Available in PATH as `surreal` or at `/Users/bri/.surrealdb/surreal`
- **Swift toolchain**: For running `swift test`
- **Integration tests configured**: Tests check for `SURREALDB_TEST=1` and skip if not set

## Usage

Invoke the skill directly:

```
/integration-tests
```

The skill will execute `.claude/skills/integration-tests/run-tests.sh` which:
- Detects if SurrealDB is already running
- Starts a temporary instance if needed
- Runs all integration tests
- Shows test results summary
- Stops SurrealDB if we started it

## Test Coverage

The integration tests (23 tests) cover:

- **Automatic schema generation** from `@Surreal` macros
- **Manual table/field/index definition** via fluent builder API
- **Edge model schemas** for graph relationships
- **Schema introspection** (describeTable, listTables, getDatabaseInfo)
- **Dry run mode** for SQL preview without execution
- **Schema modes** (schemafull vs schemaless)
- **Field constraints** (assertions, defaults, validations)
- **Index types** (unique, fulltext, search with analyzers)

## Output

The skill provides:
- Real-time progress updates during test execution
- Test result summary (passed/failed counts)
- Full test output logged to `/tmp/integration-test-results.log`

Example output:
```
🧪 SurrealDB Integration Tests
================================
🔍 Checking for running SurrealDB instance...
🚀 Starting SurrealDB...
✅ SurrealDB is ready!

🧪 Running integration tests...
================================
Test Suite 'All tests' passed at 2026-02-02 10:15:42.123.
     Executed 23 tests, with 0 failures (0 unexpected) in 2.456 (2.458) seconds

================================
✅ Integration tests completed!
```

## Notes

- **In-memory storage**: Tests use temporary in-memory database (no persistence)
- **Idempotent tests**: Each test cleans up after itself
- **Reuses existing instance**: If SurrealDB is already running, the skill uses it
- **Unit tests still run**: The 182 unit tests run without requiring SurrealDB
- **CI behavior**: In CI without SURREALDB_TEST=1, integration tests gracefully skip

## Troubleshooting

If tests fail:
1. Check SurrealDB is installed: `which surreal` or check `/Users/bri/.surrealdb/surreal`
2. Review full test output: `cat /tmp/integration-test-results.log`
3. Verify port 8000 is available: `lsof -i :8000`
4. Check SurrealDB logs: `cat /tmp/surrealdb.log`

## Implementation

The skill runs the bash script at `.claude/skills/integration-tests/run-tests.sh` which handles:
- SurrealDB process management
- Environment variable configuration
- Test execution and result parsing
- Proper cleanup on success or failure
