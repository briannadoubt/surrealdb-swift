# Testing Guide

## Unit Tests

Run unit tests without any external dependencies:

```bash
swift test
```

This runs 31 unit tests covering:
- RecordID parsing and validation
- SurrealValue encoding/decoding
- JSON-RPC protocol structures
- Query builder pattern

## Integration Tests

Integration tests require a running SurrealDB instance and test against real database operations.

### Using Docker Compose (Recommended)

1. **Start SurrealDB**:
   ```bash
   docker-compose up -d
   ```

2. **Wait for SurrealDB to be ready**:
   ```bash
   docker-compose logs -f surrealdb
   # Wait for "Started web server on 0.0.0.0:8000"
   # Or wait for health check: docker-compose ps
   ```

3. **Run integration tests**:
   ```bash
   SURREALDB_TEST=1 swift test
   ```

4. **Stop SurrealDB**:
   ```bash
   docker-compose down
   ```

### Using Local Installation

1. **Install SurrealDB**:
   ```bash
   # macOS
   brew install surrealdb/tap/surreal

   # Or using install script
   curl -sSf https://install.surrealdb.com | sh
   ```

2. **Start SurrealDB**:
   ```bash
   surreal start --user root --pass root memory
   ```

3. **Run integration tests** (in another terminal):
   ```bash
   SURREALDB_TEST=1 swift test
   ```

## Integration Test Coverage

The integration tests verify:

1. **Connection Management**
   - WebSocket connection establishment
   - Connection status checking
   - Graceful disconnection

2. **Authentication**
   - Root user authentication
   - Namespace/database selection
   - Session management

3. **CRUD Operations**
   - Create records with typed data
   - Select records (all and specific)
   - Update and merge operations
   - Delete operations

4. **Query Operations**
   - Custom SurrealQL queries
   - Variable binding
   - Result parsing

5. **Live Queries**
   - Create live query subscriptions
   - Receive CREATE notifications
   - Receive UPDATE notifications
   - Kill live queries

6. **Query Builder**
   - Fluent API execution
   - Type-safe result decoding
   - Complex query construction

7. **Relationships**
   - Create graph relationships with RELATE
   - Store edge data
   - Query relationships

## Continuous Integration

For CI environments, use the Docker Compose setup:

```yaml
# .github/workflows/test.yml example
- name: Start SurrealDB
  run: docker-compose up -d

- name: Wait for SurrealDB
  run: |
    timeout 30 bash -c 'until docker-compose exec -T surrealdb curl -f http://localhost:8000/health; do sleep 1; done'

- name: Run tests
  run: SURREALDB_TEST=1 swift test

- name: Stop SurrealDB
  run: docker-compose down
```

## Troubleshooting

### Port Already in Use

If port 8000 is already in use:
```bash
# Find what's using port 8000
lsof -i :8000

# Or change the port in docker-compose.yml
ports:
  - "8001:8000"  # Use port 8001 instead
```

Then update the test URL in `IntegrationTests.swift` if needed.

### Connection Timeout

If tests fail with connection errors:
1. Check SurrealDB is running: `docker-compose ps`
2. Check logs: `docker-compose logs surrealdb`
3. Verify health: `curl http://localhost:8000/health`

### Tests Skipped

If you see "8 tests skipped", the `SURREALDB_TEST=1` environment variable wasn't set:
```bash
# Make sure to set the environment variable
SURREALDB_TEST=1 swift test
```
