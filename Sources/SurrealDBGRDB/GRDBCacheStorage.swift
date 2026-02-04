import Foundation
import GRDB
import SurrealDB

/// Persistent cache storage backed by GRDB (SQLite).
///
/// This implementation provides persistent caching across application launches.
/// It is available on Apple platforms and Linux, but **not** WebAssembly.
///
/// For WebAssembly or platforms without SQLite, use ``InMemoryCacheStorage`` instead.
///
/// ## Usage
///
/// ```swift
/// import SurrealDB
/// import SurrealDBGRDB
///
/// let storage = try GRDBCacheStorage(path: "path/to/cache.sqlite")
/// let db = try SurrealDB(
///     url: "ws://localhost:8000/rpc",
///     cachePolicy: .default,
///     cacheStorage: storage
/// )
/// ```
///
/// ## In-Memory Mode
///
/// For testing or ephemeral storage, use the in-memory initializer:
///
/// ```swift
/// let storage = try GRDBCacheStorage()  // In-memory SQLite
/// ```
public final class GRDBCacheStorage: CacheStorage, @unchecked Sendable {
    private let dbWriter: any DatabaseWriter

    /// Creates a new GRDB cache storage with a file-based database.
    ///
    /// - Parameter path: The file path for the SQLite database.
    /// - Throws: A database error if the file cannot be opened or migrated.
    public init(path: String) throws {
        let dbPool = try DatabasePool(path: path)
        self.dbWriter = dbPool
        try Self.migrate(dbPool)
    }

    /// Creates a new GRDB cache storage with an in-memory database.
    ///
    /// Useful for testing or when persistence is not needed but you want
    /// the SQL-based query capabilities.
    ///
    /// - Throws: A database error if the database cannot be created.
    public init() throws {
        let dbQueue = try DatabaseQueue()
        self.dbWriter = dbQueue
        try Self.migrate(dbQueue)
    }

    /// Internal initializer for testing with a custom database writer.
    internal init(dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try Self.migrate(dbWriter)
    }

    // MARK: - Migration

    private static func migrate(_ dbWriter: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "cache_entries", ifNotExists: true) { table in
                table.primaryKey("key", .text).notNull()
                table.column("method", .text).notNull()
                table.column("target", .text).notNull()
                table.column("paramsHash", .text).notNull()
                table.column("value", .blob).notNull()
                table.column("tables", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.column("lastAccessedAt", .double).notNull()
                table.column("accessCount", .integer).notNull().defaults(to: 0)
                table.column("ttl", .double)
            }

            try db.create(
                index: "idx_cache_tables",
                on: "cache_entries",
                columns: ["tables"]
            )

            try db.create(
                index: "idx_cache_last_accessed",
                on: "cache_entries",
                columns: ["lastAccessedAt"]
            )
        }

        try migrator.migrate(dbWriter)
    }

    // MARK: - CacheStorage

    public func get(_ key: CacheKey) async -> CacheEntry? {
        let keyString = Self.keyString(for: key)

        do {
            return try await dbWriter.write { db -> CacheEntry? in
                guard let row = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM cache_entries WHERE key = ?",
                    arguments: [keyString]
                ) else {
                    return nil
                }

                let entry = try Self.cacheEntry(from: row)

                // Check expiration
                if entry.isExpired {
                    try db.execute(
                        sql: "DELETE FROM cache_entries WHERE key = ?",
                        arguments: [keyString]
                    )
                    return nil
                }

                // Update access metadata
                try db.execute(
                    sql: """
                        UPDATE cache_entries
                        SET lastAccessedAt = ?, accessCount = accessCount + 1
                        WHERE key = ?
                        """,
                    arguments: [Date().timeIntervalSince1970, keyString]
                )

                return entry
            }
        } catch {
            return nil
        }
    }

    public func set(_ key: CacheKey, entry: CacheEntry) async {
        let keyString = Self.keyString(for: key)

        do {
            let valueData = try JSONEncoder().encode(entry.value)
            let tablesString = entry.tables.sorted().joined(separator: ",")

            try await dbWriter.write { db in
                try db.execute(
                    sql: """
                        INSERT OR REPLACE INTO cache_entries
                        (key, method, target, paramsHash, value, tables, createdAt, lastAccessedAt, accessCount, ttl)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        keyString,
                        key.method,
                        key.target,
                        key.paramsHash,
                        valueData,
                        tablesString,
                        entry.createdAt.timeIntervalSince1970,
                        entry.lastAccessedAt.timeIntervalSince1970,
                        entry.accessCount,
                        entry.ttl
                    ]
                )
            }
        } catch {
            // Silently fail on write errors - cache is best-effort
        }
    }

    public func remove(_ key: CacheKey) async {
        let keyString = Self.keyString(for: key)

        do {
            try await dbWriter.write { db in
                try db.execute(
                    sql: "DELETE FROM cache_entries WHERE key = ?",
                    arguments: [keyString]
                )
            }
        } catch {
            // Silently fail
        }
    }

    public func removeAll() async {
        do {
            try await dbWriter.write { db in
                try db.execute(sql: "DELETE FROM cache_entries")
            }
        } catch {
            // Silently fail
        }
    }

    public func removeEntries(forTable table: String) async {
        do {
            try await dbWriter.write { db in
                // Match table name in comma-separated list
                // Handles: exact match, start of list, middle of list, end of list
                try db.execute(
                    sql: """
                        DELETE FROM cache_entries
                        WHERE tables = ?
                           OR tables LIKE ?
                           OR tables LIKE ?
                           OR tables LIKE ?
                        """,
                    arguments: [
                        table,
                        "\(table),%",
                        "%,\(table),%",
                        "%,\(table)"
                    ]
                )
            }
        } catch {
            // Silently fail
        }
    }

    public func allEntries() async -> [(key: CacheKey, entry: CacheEntry)] {
        do {
            return try await dbWriter.read { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT * FROM cache_entries ORDER BY lastAccessedAt ASC"
                )

                return try rows.compactMap { row -> (key: CacheKey, entry: CacheEntry)? in
                    let key = CacheKey(
                        method: row["method"],
                        target: row["target"],
                        paramsHash: row["paramsHash"]
                    )
                    let entry = try Self.cacheEntry(from: row)
                    return (key: key, entry: entry)
                }
            }
        } catch {
            return []
        }
    }

    public var count: Int {
        get async {
            do {
                return try await dbWriter.read { db in
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM cache_entries") ?? 0
                }
            } catch {
                return 0
            }
        }
    }

    public var isEmpty: Bool {
        get async {
            do {
                return try await dbWriter.read { db in
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM cache_entries") == 0
                }
            } catch {
                return true
            }
        }
    }

    // MARK: - Helpers

    /// Creates a unique string key from a ``CacheKey``.
    private static func keyString(for key: CacheKey) -> String {
        "\(key.method):\(key.target):\(key.paramsHash)"
    }

    /// Reconstructs a ``CacheEntry`` from a database row.
    private static func cacheEntry(from row: Row) throws -> CacheEntry {
        let valueData: Data = row["value"]
        let value = try JSONDecoder().decode(SurrealValue.self, from: valueData)

        let tablesString: String = row["tables"]
        let tables: Set<String>
        if tablesString.isEmpty {
            tables = []
        } else {
            tables = Set(tablesString.split(separator: ",").map(String.init))
        }

        let createdAt = Date(timeIntervalSince1970: row["createdAt"])
        let lastAccessedAt = Date(timeIntervalSince1970: row["lastAccessedAt"])
        let accessCount: Int = row["accessCount"]
        let ttl: TimeInterval? = row["ttl"]

        return CacheEntry(
            value: value,
            tables: tables,
            createdAt: createdAt,
            lastAccessedAt: lastAccessedAt,
            accessCount: accessCount,
            ttl: ttl
        )
    }
}
