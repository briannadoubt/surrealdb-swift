import Foundation

// MARK: - Cache Management

extension SurrealDB {
    /// Invalidates all entries in the cache.
    ///
    /// Call this to force all subsequent queries to fetch fresh data from the server.
    public func invalidateCache() async {
        await cache?.invalidateAll()
    }

    /// Invalidates cache entries associated with a specific table.
    ///
    /// - Parameter table: The table name whose cache entries should be invalidated.
    public func invalidateCache(table: String) async {
        await cache?.invalidate(table: table)
    }

    /// Returns statistics about the current cache state.
    ///
    /// Returns `nil` if caching is not enabled.
    public func cacheStats() async -> CacheStats? {
        await cache?.stats()
    }

    // MARK: - Table Name Extraction

    /// Extracts the table name from a target string (e.g., "users:123" -> "users").
    internal static func extractTableName(from target: String) -> String {
        if let colonIndex = target.firstIndex(of: ":") {
            return String(target[target.startIndex..<colonIndex])
        }
        return target
    }

    /// Extracts table names from a SurrealQL query string (best-effort).
    internal static func extractTableNames(from sql: String) -> Set<String> {
        var tables = Set<String>()

        // Match common SurrealQL patterns: FROM table, INTO table, UPDATE table, etc.
        let patterns = [
            "(?i)FROM\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)INTO\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)UPDATE\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)CREATE\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)DELETE\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
            "(?i)UPSERT\\s+([a-zA-Z_][a-zA-Z0-9_]*)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(sql.startIndex..., in: sql)
                let matches = regex.matches(in: sql, range: range)
                for match in matches {
                    if let tableRange = Range(match.range(at: 1), in: sql) {
                        tables.insert(String(sql[tableRange]))
                    }
                }
            }
        }

        return tables
    }
}
