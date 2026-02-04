import Foundation
import JavaScriptKit
import SurrealDB

/// localStorage-backed cache storage for WASM environments.
///
/// Provides persistent caching in browsers using the Web Storage API.
/// Data persists across page reloads within the same origin.
///
/// ## Usage
///
/// ```swift
/// #if os(WASM)
/// import SurrealDBLocalStorage
///
/// let storage = LocalStorageCacheStorage(prefix: "surrealdb_cache_")
/// let db = try SurrealDB(
///     url: "ws://localhost:8000/rpc",
///     cachePolicy: .default,
///     cacheStorage: storage
/// )
/// #endif
/// ```
///
/// ## Storage Limits
///
/// Browser localStorage typically has a 5-10MB quota per origin.
/// Consider implementing eviction strategies if approaching limits.
///
/// ## Security Considerations
///
/// Data stored in localStorage is:
/// - Visible in browser developer tools
/// - Not encrypted by default
/// - Accessible to all scripts from the same origin
/// - Persists until explicitly cleared
@available(macOS 13.0, iOS 16.0, *)
public actor LocalStorageCacheStorage: CacheStorage {
    private let localStorage: JSObject
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let keyPrefix: String

    // In-memory index for quick lookups (persisted to localStorage)
    private var index: [String: CacheMetadata] = [:]

    private struct CacheMetadata: Codable {
        let tables: Set<String>
        let createdAt: Date
        var lastAccessedAt: Date
        var accessCount: Int
    }

    /// Creates a new localStorage-backed cache storage.
    ///
    /// - Parameter prefix: The key prefix for localStorage entries. Defaults to "surrealdb_cache_".
    public init(prefix: String = "surrealdb_cache_") {
        self.localStorage = JSObject.global.localStorage.object!
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.keyPrefix = prefix

        // Note: Can't call loadIndex() here due to actor isolation
        // Index will be loaded lazily on first access
    }

    private func ensureIndexLoaded() {
        guard index.isEmpty else { return }
        let result = localStorage.getItem!(indexKey())
        guard !result.isNull, let indexJSON = result.string else { return }
        let data = Data(indexJSON.utf8)
        index = (try? decoder.decode([String: CacheMetadata].self, from: data)) ?? [:]
    }

    private func storageKey(for key: CacheKey) -> String {
        keyPrefix + key.toStorageKey()
    }

    private func indexKey() -> String {
        keyPrefix + "index"
    }

    private func saveIndex() {
        guard let data = try? encoder.encode(index) else { return }
        guard let json = String(data: data, encoding: .utf8) else { return }
        _ = localStorage.setItem!(indexKey(), json)
    }

    public func get(_ key: CacheKey) async -> CacheEntry? {
        ensureIndexLoaded()
        let storageKey = storageKey(for: key)

        // Check if exists in index
        guard var metadata = index[storageKey] else { return nil }

        // Get from localStorage
        let result = localStorage.getItem!(storageKey)
        guard !result.isNull, let json = result.string else {
            // Cleanup stale index entry
            index.removeValue(forKey: storageKey)
            saveIndex()
            return nil
        }

        let data = Data(json.utf8)
        guard let entry = try? decoder.decode(CacheEntry.self, from: data) else { return nil }

        // Check expiration
        if entry.isExpired {
            _ = localStorage.removeItem!(storageKey)
            index.removeValue(forKey: storageKey)
            saveIndex()
            return nil
        }

        // Update access metadata by creating a new entry with updated values
        let updatedEntry = CacheEntry(
            value: entry.value,
            tables: entry.tables,
            createdAt: entry.createdAt,
            lastAccessedAt: Date(),
            accessCount: entry.accessCount + 1,
            ttl: entry.ttl
        )

        metadata.lastAccessedAt = updatedEntry.lastAccessedAt
        metadata.accessCount = updatedEntry.accessCount
        index[storageKey] = metadata

        // Save updated entry
        if let updatedData = try? encoder.encode(updatedEntry),
           let updatedJSON = String(data: updatedData, encoding: .utf8) {
            _ = localStorage.setItem!(storageKey, updatedJSON)
        }

        saveIndex()
        return updatedEntry
    }

    public func set(_ key: CacheKey, entry: CacheEntry) async {
        ensureIndexLoaded()
        let storageKey = storageKey(for: key)

        guard let data = try? encoder.encode(entry) else { return }
        guard let json = String(data: data, encoding: .utf8) else { return }

        // Store in localStorage
        _ = localStorage.setItem!(storageKey, json)

        // Update index
        index[storageKey] = CacheMetadata(
            tables: entry.tables,
            createdAt: entry.createdAt,
            lastAccessedAt: entry.lastAccessedAt,
            accessCount: entry.accessCount
        )
        saveIndex()
    }

    public func remove(_ key: CacheKey) async {
        ensureIndexLoaded()
        let storageKey = storageKey(for: key)
        _ = localStorage.removeItem!(storageKey)
        index.removeValue(forKey: storageKey)
        saveIndex()
    }

    public func removeAll() async {
        ensureIndexLoaded()
        // Remove all entries with our prefix
        for storageKey in index.keys {
            _ = localStorage.removeItem!(storageKey)
        }

        // Clear index
        index.removeAll()
        _ = localStorage.removeItem!(indexKey())
    }

    public func removeEntries(forTable table: String) async {
        ensureIndexLoaded()
        let keysToRemove = index.filter { $0.value.tables.contains(table) }.map(\.key)

        for storageKey in keysToRemove {
            _ = localStorage.removeItem!(storageKey)
            index.removeValue(forKey: storageKey)
        }

        saveIndex()
    }

    public func allEntries() async -> [(key: CacheKey, entry: CacheEntry)] {
        ensureIndexLoaded()
        var entries: [(key: CacheKey, entry: CacheEntry)] = []

        for (storageKey, _) in index {
            let result = localStorage.getItem!(storageKey)
            guard !result.isNull, let json = result.string else { continue }
            let data = Data(json.utf8)
            guard let entry = try? decoder.decode(CacheEntry.self, from: data) else { continue }

            // Reconstruct CacheKey from storage key
            let keyString = String(storageKey.dropFirst(keyPrefix.count))
            let parts = keyString.split(separator: ":", maxSplits: 2).map(String.init)
            guard parts.count == 3 else { continue }

            let cacheKey = CacheKey(method: parts[0], target: parts[1], paramsHash: parts[2])
            entries.append((key: cacheKey, entry: entry))
        }

        // Sort by lastAccessedAt (oldest first) for LRU
        return entries.sorted { $0.entry.lastAccessedAt < $1.entry.lastAccessedAt }
    }

    public var count: Int {
        ensureIndexLoaded()
        return index.count
    }

    public var isEmpty: Bool {
        ensureIndexLoaded()
        return index.isEmpty
    }
}
