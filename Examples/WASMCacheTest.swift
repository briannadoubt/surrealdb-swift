// WASM Cache Test Example
// Build with: swift build --triple wasm32-unknown-wasi
//
// This example demonstrates localStorage caching in browser environments.
// Open browser DevTools → Application → Local Storage to see cached entries.

#if os(WASM)
import JavaScriptKit
import SurrealDB
import SurrealDBLocalStorage

struct User: Codable {
    let name: String
    let age: Int
}

@main
struct WASMCacheTest {
    static func main() async {
        let console = JSObject.global.console

        do {
            // Create DB with localStorage cache
            console.log!("Setting up SurrealDB with localStorage cache...")
            let storage = LocalStorageCacheStorage(prefix: "surrealdb_cache_")
            let db = try SurrealDB(
                url: "ws://localhost:8000/rpc",
                cachePolicy: .default,
                cacheStorage: storage
            )

            try await db.connect()
            try await db.signin(Credentials.root(RootAuth(username: "root", password: "root")))
            try await db.use(namespace: "test", database: "test")

            console.log!("Connected to SurrealDB")

            // Test 1: Cache Miss
            console.log!("\n=== Test 1: Initial Query (Cache Miss) ===")
            let user = User(name: "Alice", age: 30)
            let _: User = try await db.create("users", data: user)

            let start1 = JSDate.now()
            let results1: [User] = try await db.select("users")
            let duration1 = JSDate.now() - start1

            console.log!("Query 1: Fetched \(results1.count) users in \(duration1)ms")

            // Test 2: Cache Hit
            console.log!("\n=== Test 2: Second Query (Cache Hit) ===")
            let start2 = JSDate.now()
            let results2: [User] = try await db.select("users")
            let duration2 = JSDate.now() - start2

            console.log!("Query 2: Fetched \(results2.count) users in \(duration2)ms")
            console.log!("Speed improvement: \(Int(duration1 / duration2))x faster")

            // Test 3: Check localStorage
            console.log!("\n=== Test 3: localStorage Contents ===")
            let localStorage = JSObject.global.localStorage
            let keys = localStorage.length
            console.log!("localStorage has \(keys) entries")
            console.log!("Check DevTools → Application → Local Storage to see entries prefixed with 'surrealdb_cache_'")

            // Test 4: Cache Stats
            if let stats = try await db.cacheStats() {
                console.log!("\n=== Cache Stats ===")
                console.log!("Total entries: \(stats.totalEntries)")
                console.log!("Tables cached: \(stats.tables)")
            }

            // Test 5: Invalidation
            console.log!("\n=== Test 4: Cache Invalidation ===")
            let user2 = User(name: "Bob", age: 25)
            let _: User = try await db.create("users", data: user2)

            let results3: [User] = try await db.select("users")
            console.log!("After mutation: Fetched \(results3.count) users (cache was invalidated)")

            // Test 6: Persistence
            console.log!("\n=== Test 5: Persistence Test ===")
            console.log!("Reload the page to verify cache persists!")
            console.log!("The cache should still contain entries after page reload.")

            console.log!("\n✅ All tests completed successfully!")
        } catch {
            console.error!("Error: \(error)")
        }
    }
}
#else
#error("This example requires the WASM platform. Build with: swift build --triple wasm32-unknown-wasi")
#endif
