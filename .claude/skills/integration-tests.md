# Integration Tests Skill

Run SurrealDB integration tests for the Swift client.

## Usage

```
/integration-tests
```

## What This Skill Does

1. Checks if SurrealDB is running on localhost:8000
2. If not running, starts SurrealDB in memory mode
3. Runs the integration test suite with `SURREALDB_TEST=1`
4. Reports the results
5. Optionally cleans up the SurrealDB instance after tests complete

## Requirements

- SurrealDB installed (available at `/Users/bri/.surrealdb/surreal` or in PATH)
- Swift toolchain installed
- Integration tests properly configured with `SURREALDB_TEST=1` guard

## Expected Behavior

The skill will:
- ✅ Start SurrealDB if not already running
- ✅ Run all integration tests (currently 23 tests)
- ✅ Display test results clearly
- ✅ Report any failures with details
- ✅ Clean up resources after completion

## Test Categories

The integration tests cover:
- Automatic schema generation from `@Surreal` macros
- Manual table/field/index definition via builders
- Edge model schema generation
- Schema introspection (describeTable, listTables)
- Dry run mode validation
- Schema modes (schemafull vs schemaless)

## Notes

- Integration tests require a running SurrealDB instance
- Tests use in-memory storage and don't persist data
- Tests are designed to be idempotent and clean up after themselves
- If SurrealDB is already running, the skill will use the existing instance
