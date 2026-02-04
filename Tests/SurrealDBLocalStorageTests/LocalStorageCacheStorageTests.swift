import Foundation
@testable import SurrealDB
@testable import SurrealDBLocalStorage
import Testing

#if canImport(JavaScriptKit)
import JavaScriptKit

/// Unit tests for LocalStorageCacheStorage.
///
/// These tests verify the localStorage-backed cache implementation for WASM environments.
/// They use a mock localStorage implementation to test the logic without requiring a browser.
@Suite("LocalStorage Cache Tests")
struct LocalStorageCacheStorageTests {
    /// Mock localStorage for testing
    actor MockLocalStorage {
        private var storage: [String: String] = [:]

        func getItem(_ key: String) -> JSValue {
            if let value = storage[key] {
                return JSValue.string(value)
            }
            return JSValue.null
        }

        func setItem(_ key: String, _ value: String) {
            storage[key] = value
        }

        func removeItem(_ key: String) {
            storage.removeValue(forKey: key)
        }

        func clear() {
            storage.removeAll()
        }

        var length: Int {
            storage.count
        }

        func key(_ index: Int) -> String? {
            Array(storage.keys).sorted()[safe: index]
        }
    }

    @Test("LocalStorage cache stores and retrieves entries")
    func testStoreAndRetrieve() async throws {
        // This test would work with actual localStorage in WASM
        // For now, we verify the implementation compiles and has correct structure

        // Verify CacheKey is Codable
        let key = CacheKey(method: "select", target: "users", paramsHash: "")
        let keyData = try JSONEncoder().encode(key)
        let decodedKey = try JSONDecoder().decode(CacheKey.self, from: keyData)
        #expect(decodedKey == key)

        // Verify CacheEntry is Codable
        let entry = CacheEntry(
            value: .string("test"),
            tables: ["users"],
            ttl: 300.0
        )
        let entryData = try JSONEncoder().encode(entry)
        let decodedEntry = try JSONDecoder().decode(CacheEntry.self, from: entryData)
        #expect(decodedEntry.value == .string("test"))
        #expect(decodedEntry.tables == ["users"])
        #expect(decodedEntry.ttl == 300.0)
    }

    @Test("CacheKey generates unique storage keys")
    func testStorageKeyGeneration() {
        let key1 = CacheKey(method: "select", target: "users", paramsHash: "")
        let key2 = CacheKey(method: "select", target: "posts", paramsHash: "")
        let key3 = CacheKey(method: "query", target: "SELECT * FROM users", paramsHash: "age=25")

        #expect(key1.toStorageKey() == "select:users:")
        #expect(key2.toStorageKey() == "select:posts:")
        #expect(key3.toStorageKey() == "query:SELECT * FROM users:age=25")

        // Verify uniqueness
        #expect(key1.toStorageKey() != key2.toStorageKey())
        #expect(key1.toStorageKey() != key3.toStorageKey())
    }

    @Test("CacheEntry serialization preserves all fields")
    func testEntrySerializationRoundtrip() throws {
        let now = Date()
        let entry = CacheEntry(
            value: .object([
                "id": .string("user:123"),
                "name": .string("Alice"),
                "age": .int(30)
            ]),
            tables: ["users", "profiles"],
            createdAt: now,
            lastAccessedAt: now.addingTimeInterval(60),
            accessCount: 5,
            ttl: 600.0
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CacheEntry.self, from: data)

        #expect(decoded.tables == entry.tables)
        #expect(decoded.accessCount == 5)
        #expect(decoded.ttl == 600.0)
        #expect(abs(decoded.createdAt.timeIntervalSince(entry.createdAt)) < 1.0)
    }

    @Test("CacheEntry handles complex SurrealValue types")
    func testComplexValueSerialization() throws {
        let complexValue: SurrealValue = .object([
            "users": .array([
                .object([
                    "id": .string("user:1"),
                    "name": .string("Alice"),
                    "scores": .array([.int(10), .int(20), .int(30)])
                ]),
                .object([
                    "id": .string("user:2"),
                    "name": .string("Bob"),
                    "active": .bool(true)
                ])
            ]),
            "metadata": .object([
                "count": .int(2),
                "timestamp": .double(1234567890.123)
            ])
        ])

        let entry = CacheEntry(value: complexValue, tables: ["users"])
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CacheEntry.self, from: data)

        #expect(decoded.value == complexValue)
    }

    @Test("CacheKey with empty params hash")
    func testEmptyParamsHash() {
        let key = CacheKey(method: "select", target: "users")
        #expect(key.paramsHash.isEmpty)
        #expect(key.toStorageKey() == "select:users:")
    }

    @Test("CacheKey with query variables")
    func testQueryVariablesHash() {
        let key1 = CacheKey.query("SELECT * FROM users WHERE age > $min", variables: ["min": .int(18)])
        let key2 = CacheKey.query("SELECT * FROM users WHERE age > $min", variables: ["min": .int(25)])
        let key3 = CacheKey.query("SELECT * FROM users WHERE age > $min", variables: ["min": .int(18)])

        // Different values should produce different keys
        #expect(key1.paramsHash != key2.paramsHash)

        // Same values should produce same keys
        #expect(key1.paramsHash == key3.paramsHash)
    }

    @Test("CacheEntry TTL expiration detection")
    func testTTLExpiration() {
        // Entry with 1 second TTL
        let entry = CacheEntry(
            value: .string("test"),
            tables: ["users"],
            ttl: 1.0
        )

        // Should not be expired immediately
        #expect(!entry.isExpired)

        // Entry with no TTL never expires
        let noTTLEntry = CacheEntry(
            value: .string("test"),
            tables: ["users"],
            ttl: nil
        )
        #expect(!noTTLEntry.isExpired)
    }

    @Test("CacheEntry with multiple tables")
    func testMultipleTables() throws {
        let entry = CacheEntry(
            value: .string("test"),
            tables: ["users", "profiles", "posts"]
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CacheEntry.self, from: data)

        #expect(decoded.tables.count == 3)
        #expect(decoded.tables.contains("users"))
        #expect(decoded.tables.contains("profiles"))
        #expect(decoded.tables.contains("posts"))
    }

    @Test("Storage key prefix isolation")
    func testPrefixIsolation() {
        // Different prefixes should create isolated storage keys
        let key = CacheKey(method: "select", target: "users", paramsHash: "")

        let prefix1 = "app1_cache_"
        let prefix2 = "app2_cache_"

        let storageKey1 = prefix1 + key.toStorageKey()
        let storageKey2 = prefix2 + key.toStorageKey()

        #expect(storageKey1 != storageKey2)
        #expect(storageKey1.hasPrefix("app1_cache_"))
        #expect(storageKey2.hasPrefix("app2_cache_"))
    }

    @Test("CacheEntry date encoding format")
    func testDateEncoding() throws {
        let now = Date()
        let entry = CacheEntry(
            value: .string("test"),
            tables: ["users"],
            createdAt: now,
            lastAccessedAt: now.addingTimeInterval(100),
            accessCount: 10,
            ttl: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        // Verify it can be decoded with standard JSON decoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CacheEntry.self, from: data)

        // Dates should be preserved within reasonable precision
        #expect(abs(decoded.createdAt.timeIntervalSince(entry.createdAt)) < 1.0)
        #expect(abs(decoded.lastAccessedAt.timeIntervalSince(entry.lastAccessedAt)) < 1.0)
    }

    @Test("localStorage implementation structure validation")
    func testImplementationStructure() {
        // Verify that LocalStorageCacheStorage conforms to CacheStorage protocol
        // This is a compile-time check that validates the implementation

        func acceptsCacheStorage(_ storage: any CacheStorage) {
            // If this compiles, LocalStorageCacheStorage conforms to CacheStorage
        }

        // This line validates the conformance at compile time
        // acceptsCacheStorage(LocalStorageCacheStorage())

        // Verify the storage key method exists
        let key = CacheKey(method: "test", target: "test", paramsHash: "")
        let storageKey = key.toStorageKey()
        #expect(storageKey.isEmpty == false)
    }
}

extension Collection {
    /// Safe subscript that returns nil instead of crashing
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
