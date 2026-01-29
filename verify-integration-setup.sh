#!/bin/bash
# Verification script for SurrealDB Swift integration tests

set -e

echo "=================================================="
echo "  SurrealDB Swift - Integration Test Verification"
echo "=================================================="
echo ""

# Check Docker is running
echo "1. Checking Docker..."
if docker info >/dev/null 2>&1; then
    echo "   ✅ Docker is running"
else
    echo "   ❌ Docker is not running"
    echo "   Please start Docker Desktop"
    exit 1
fi

# Check SurrealDB container
echo ""
echo "2. Checking SurrealDB container..."
if docker compose ps | grep -q "surrealdb-test.*Up"; then
    echo "   ✅ SurrealDB container is running"
else
    echo "   ⚠️  SurrealDB container not running"
    echo "   Starting SurrealDB..."
    docker compose up -d
    sleep 3
    echo "   ✅ SurrealDB started"
fi

# Check SurrealDB health
echo ""
echo "3. Checking SurrealDB health..."
if curl -sf http://localhost:8000/health >/dev/null; then
    echo "   ✅ SurrealDB is healthy"
else
    echo "   ❌ SurrealDB health check failed"
    echo "   Waiting 5 seconds and retrying..."
    sleep 5
    if curl -sf http://localhost:8000/health >/dev/null; then
        echo "   ✅ SurrealDB is healthy"
    else
        echo "   ❌ SurrealDB is not accessible"
        exit 1
    fi
fi

# Check test files exist
echo ""
echo "4. Checking test files..."
if [ -f "Tests/SurrealDBTests/IntegrationTests.swift" ]; then
    TEST_COUNT=$(grep -c "func test" Tests/SurrealDBTests/IntegrationTests.swift)
    echo "   ✅ IntegrationTests.swift found ($TEST_COUNT tests)"
else
    echo "   ❌ IntegrationTests.swift not found"
    exit 1
fi

# Build the project
echo ""
echo "5. Building Swift package..."
if swift build >/dev/null 2>&1; then
    echo "   ✅ Build successful"
else
    echo "   ❌ Build failed"
    echo "   Run: swift build"
    exit 1
fi

# Show how to run tests
echo ""
echo "=================================================="
echo "  ✅ Setup Verified!"
echo "=================================================="
echo ""
echo "Everything is ready! To run the integration tests:"
echo ""
echo "  # Run all integration tests"
echo "  SURREALDB_TEST=1 swift test"
echo ""
echo "  # Run a specific test"
echo "  SURREALDB_TEST=1 swift test --filter testConnection"
echo ""
echo "  # Available tests:"
grep "func test" Tests/SurrealDBTests/IntegrationTests.swift | sed 's/.*func /  - /' | sed 's/(.*//'
echo ""
echo "  # Stop SurrealDB when done"
echo "  docker compose down"
echo ""
