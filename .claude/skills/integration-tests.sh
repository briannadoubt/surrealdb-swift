#!/bin/bash
set -e

# Integration Tests Skill for SurrealDB Swift Client
# Runs integration tests with SurrealDB instance

SURREAL_PATH="/Users/bri/.surrealdb/surreal"
SURREAL_PORT=8000

echo "🧪 SurrealDB Integration Tests"
echo "================================"

# Check if SurrealDB is installed
if [ ! -f "$SURREAL_PATH" ] && ! command -v surreal &> /dev/null; then
    echo "❌ SurrealDB not found!"
    echo "   Install with: curl -sSf https://install.surrealdb.com | sh"
    exit 1
fi

# Use PATH version if available, otherwise use specific path
if command -v surreal &> /dev/null; then
    SURREAL_CMD="surreal"
else
    SURREAL_CMD="$SURREAL_PATH"
fi

# Check if SurrealDB is already running
echo "🔍 Checking for running SurrealDB instance..."
if curl -s http://localhost:$SURREAL_PORT/health > /dev/null 2>&1; then
    echo "✅ SurrealDB is already running on port $SURREAL_PORT"
    STARTED_SURREAL=false
else
    echo "🚀 Starting SurrealDB..."
    $SURREAL_CMD start --log warn --user root --pass root memory > /tmp/surrealdb.log 2>&1 &
    SURREAL_PID=$!
    STARTED_SURREAL=true

    # Wait for SurrealDB to be ready
    echo "⏳ Waiting for SurrealDB to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:$SURREAL_PORT/health > /dev/null 2>&1; then
            echo "✅ SurrealDB is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "❌ SurrealDB failed to start after 30 seconds"
            if [ "$STARTED_SURREAL" = true ]; then
                kill $SURREAL_PID 2>/dev/null || true
            fi
            exit 1
        fi
        sleep 1
    done
fi

# Run integration tests
echo ""
echo "🧪 Running integration tests..."
echo "================================"

# Set environment variable and run tests
export SURREALDB_TEST=1

if swift test 2>&1 | tee /tmp/integration-test-results.log; then
    echo ""
    echo "================================"
    echo "✅ Integration tests completed!"

    # Show summary
    grep -E "(Test run with|passed|failed)" /tmp/integration-test-results.log | tail -5
else
    echo ""
    echo "================================"
    echo "❌ Integration tests failed!"
    echo ""
    echo "Recent output:"
    tail -20 /tmp/integration-test-results.log
    EXIT_CODE=1
fi

# Clean up if we started SurrealDB
if [ "$STARTED_SURREAL" = true ]; then
    echo ""
    echo "🧹 Cleaning up SurrealDB..."
    kill $SURREAL_PID 2>/dev/null || true
    echo "✅ SurrealDB stopped"
fi

exit ${EXIT_CODE:-0}
