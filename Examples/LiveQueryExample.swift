import Foundation
import SurrealDB

// This example demonstrates live query functionality.
// To run this example:
// 1. Start SurrealDB: surreal start --user root --pass root memory
// 2. Run: swift run LiveQueryExample

@main
struct LiveQueryExample {
    static func main() async throws {
        // Create and connect to SurrealDB
        let db = try SurrealDB(url: "ws://localhost:8000/rpc", transportType: .websocket)
        try await db.connect()

        // Authenticate
        try await db.signin(.root(RootAuth(username: "root", password: "root")))
        try await db.use(namespace: "test", database: "test")

        print("Starting live query on 'products' table...")

        // Create a live query
        let (queryId, stream) = try await db.live("products")

        // Start listening for changes in a background task
        let listenTask = Task {
            print("Listening for changes...")
            for await notification in stream {
                switch notification.action {
                case .create:
                    print("✅ CREATE:", notification.result)
                case .update:
                    print("🔄 UPDATE:", notification.result)
                case .delete:
                    print("❌ DELETE:", notification.result)
                case .close:
                    print("🔒 CLOSE: Live query closed")
                }
            }
        }

        // Give the live query a moment to initialize
        try await Task.sleep(for: .milliseconds(100))

        // Define a product model
        struct Product: Codable {
            let name: String
            let price: Double
        }

        // Perform some operations that will trigger notifications
        print("\nPerforming operations...")

        print("Creating product 1...")
        let _: Product = try await db.create(
            "products:laptop",
            data: Product(name: "Laptop", price: 999.99)
        )

        try await Task.sleep(for: .milliseconds(100))

        print("Creating product 2...")
        let _: Product = try await db.create(
            "products:mouse",
            data: Product(name: "Mouse", price: 29.99)
        )

        try await Task.sleep(for: .milliseconds(100))

        print("Updating product 1...")
        let _: Product = try await db.merge(
            "products:laptop",
            data: ["price": 899.99]
        )

        try await Task.sleep(for: .milliseconds(100))

        print("Deleting product 2...")
        try await db.delete("products:mouse")

        // Wait a bit for all notifications to arrive
        try await Task.sleep(for: .seconds(1))

        // Kill the live query
        print("\nStopping live query...")
        try await db.kill(queryId)

        // Wait for the listen task to complete
        await listenTask.value

        // Cleanup
        print("\nCleaning up...")
        try await db.delete("products")

        try await db.disconnect()
        print("Disconnected.")
    }
}
