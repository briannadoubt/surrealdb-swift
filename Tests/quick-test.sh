#!/bin/bash
set -e

echo "=== Quick Integration Test ==="
echo ""
echo "1. Checking SurrealDB health..."
curl -sf http://localhost:8000/health && echo " ✅ SurrealDB is healthy" || (echo " ❌ SurrealDB not accessible" && exit 1)

echo ""
echo "2. Building Swift package..."
swift build --quiet

echo ""
echo "3. Running integration tests..."
SURREALDB_TEST=1 swift test 2>&1 | tee /tmp/surrealdb-test.log

echo ""
echo "=== Test Results ==="
grep -E "(Test Suite|Executed|passed|failed)" /tmp/surrealdb-test.log | tail -20
