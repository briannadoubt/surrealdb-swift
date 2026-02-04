import Foundation

/// In-memory cache storage backed by a Swift dictionary.
///
/// This implementation works on all platforms including WebAssembly.
/// Data is not persisted across application launches.
///
/// Thread safety is guaranteed by the `actor` isolation model.
public actor InMemoryCacheStorage: CacheStorage {
    private var entries: [CacheKey: CacheEntry] = [:]

    /// Creates a new in-memory cache storage.
    public init() {}

    public func get(_ key: CacheKey) async -> CacheEntry? {
        guard var entry = entries[key] else { return nil }

        if entry.isExpired {
            entries.removeValue(forKey: key)
            return nil
        }

        entry.lastAccessedAt = Date()
        entry.accessCount += 1
        entries[key] = entry

        return entry
    }

    public func set(_ key: CacheKey, entry: CacheEntry) async {
        entries[key] = entry
    }

    public func remove(_ key: CacheKey) async {
        entries.removeValue(forKey: key)
    }

    public func removeAll() async {
        entries.removeAll()
    }

    public func removeEntries(forTable table: String) async {
        let keysToRemove = entries.filter { $0.value.tables.contains(table) }.map(\.key)
        for key in keysToRemove {
            entries.removeValue(forKey: key)
        }
    }

    public func allEntries() async -> [(key: CacheKey, entry: CacheEntry)] {
        entries.map { (key: $0.key, entry: $0.value) }
            .sorted { $0.entry.lastAccessedAt < $1.entry.lastAccessedAt }
    }

    public var count: Int {
        entries.count
    }
}
