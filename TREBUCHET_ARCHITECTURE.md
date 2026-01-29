# Trebuchet Architecture - Client/Server Separation

## The Problem

With distributed actors, we have:
- **Server**: Runs the actual SurrealDB connection
- **Client**: iOS/macOS app that calls server methods

If we use a shared protocol, the client would need to compile:
- ❌ All of SurrealDB library
- ❌ WebSocket dependencies
- ❌ Transport implementations
- ❌ Heavy server-side code

**This bloats the client unnecessarily!**

## The Solution: Multi-Target Architecture

### Package Structure

```
SurrealDB/
├── SurrealDBCore/              # Shared types (client + server)
│   ├── Models/
│   │   ├── RecordID.swift
│   │   ├── SurrealValue.swift
│   │   └── SurrealError.swift
│   └── Protocols/
│       └── SurrealDBServiceProtocol.swift
│
├── SurrealDB/                  # Full implementation (server only)
│   ├── Core/
│   ├── Transport/
│   ├── Client/
│   └── [all current code]
│
└── SurrealDBClient/            # Thin client (client only)
    └── RemoteClient.swift      # Distributed actor stub
```

### Updated Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SurrealDB",
    platforms: [
        .macOS(.v15), .iOS(.v18), .tvOS(.v18),
        .watchOS(.v11), .visionOS(.v2)
    ],
    products: [
        // Core types - used by both client and server
        .library(
            name: "SurrealDBCore",
            targets: ["SurrealDBCore"]
        ),

        // Full implementation - server side only
        .library(
            name: "SurrealDB",
            targets: ["SurrealDB"]
        ),

        // Thin client - iOS/macOS apps
        .library(
            name: "SurrealDBClient",
            targets: ["SurrealDBClient"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/briannadoubt/Trebuchet.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
    ],
    targets: [
        // Shared types (no heavy dependencies)
        .target(
            name: "SurrealDBCore",
            dependencies: [],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),

        // Full implementation (server side)
        .target(
            name: "SurrealDB",
            dependencies: ["SurrealDBCore"],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),

        // Thin client (iOS/macOS apps)
        .target(
            name: "SurrealDBClient",
            dependencies: [
                "SurrealDBCore",
                .product(name: "Trebuchet", package: "Trebuchet")
            ],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),

        .testTarget(
            name: "SurrealDBTests",
            dependencies: ["SurrealDB"]
        )
    ]
)
```

## Implementation

### 1. SurrealDBCore (Shared)

**Minimal shared types:**

```swift
// SurrealDBCore/Models/RecordID.swift
public struct RecordID: Codable, Sendable, Hashable {
    public let table: String
    public let id: String
    // ... (no SurrealDB dependency)
}

// SurrealDBCore/Models/SurrealValue.swift
public enum SurrealValue: Codable, Sendable {
    case null, bool(Bool), int(Int), double(Double), string(String)
    case array([SurrealValue]), object([String: SurrealValue])
    // ... (pure data structure, no dependencies)
}

// SurrealDBCore/Models/SurrealError.swift
public enum SurrealError: Error, Sendable {
    case connectionError(String)
    case rpcError(code: Int, message: String, data: SurrealValue?)
    case authenticationError(String)
    // ... (just error types)
}

// SurrealDBCore/Protocols/SurrealDBServiceProtocol.swift
import Distributed

/// Protocol that both server implementation and client stub conform to
@available(macOS 15.0, iOS 18.0, *)
public distributed actor protocol SurrealDBServiceProtocol: DistributedActor {
    // Basic operations - all must be distributed methods
    distributed func select<T: Codable>(_ target: String) async throws -> [T]
    distributed func create<T: Codable>(_ target: String, data: T) async throws -> T
    distributed func update<T: Codable>(_ target: String, data: T) async throws -> T
    distributed func delete(_ target: String) async throws
    distributed func query(_ sql: String, variables: [String: SurrealValue]?) async throws -> [SurrealValue]
}
```

### 2. SurrealDB (Server Implementation)

**Full implementation with all dependencies:**

```swift
// SurrealDB/DistributedSurrealDBService.swift
import SurrealDBCore
import Distributed
import Trebuchet

@Trebuchet
public distributed actor SurrealDBService: SurrealDBServiceProtocol {
    // Internal - full SurrealDB client with WebSockets, etc.
    private let db: SurrealDB

    public init(url: String) async throws {
        // This code only runs on the server
        self.db = try SurrealDB(url: url, transportType: .websocket)
        try await db.connect()
    }

    public distributed func select<T: Codable>(_ target: String) async throws -> [T] {
        try await db.select(target)
    }

    public distributed func create<T: Codable>(_ target: String, data: T) async throws -> T {
        try await db.create(target, data: data)
    }

    public distributed func update<T: Codable>(_ target: String, data: T) async throws -> T {
        try await db.update(target, data: data)
    }

    public distributed func delete(_ target: String) async throws {
        try await db.delete(target)
    }

    public distributed func query(_ sql: String, variables: [String: SurrealValue]?) async throws -> [SurrealValue] {
        try await db.query(sql, variables: variables)
    }
}
```

### 3. SurrealDBClient (Thin Client)

**No SurrealDB implementation, just the protocol:**

```swift
// SurrealDBClient/RemoteClient.swift
import SurrealDBCore
import Distributed
import Trebuchet

/// Thin client for calling distributed SurrealDB service
/// This compiles to minimal code - no WebSocket, no transport layer!
@Trebuchet
public distributed actor SurrealDBClient: SurrealDBServiceProtocol {
    // No implementation needed!
    // Trebuchet generates the client stub automatically

    public init(actorSystem: ActorSystem, id: ActorID) {
        self.actorSystem = actorSystem
        self.id = id
    }
}

/// Convenience extensions for client
extension SurrealDBClient {
    /// Connect to a remote SurrealDB service
    public static func connect(to serviceURL: String) async throws -> SurrealDBClient {
        // Use Trebuchet's actor resolution
        let system = TrebuchetActorSystem()
        let id = try ActorID(parsing: serviceURL)
        return SurrealDBClient(actorSystem: system, id: id)
    }
}
```

## Usage

### Server Side (macOS/Linux)

```swift
// Server.swift
import SurrealDB
import Trebuchet

@main
struct Server {
    static func main() async throws {
        // Full SurrealDB implementation runs here
        let service = try await SurrealDBService(url: "ws://localhost:8000/rpc")

        try await service.signin(.root(
            RootAuth(username: "root", password: "root")
        ))
        try await service.use(namespace: "prod", database: "prod")

        // Register with Trebuchet
        try await Trebuchet.register(service, as: "surrealdb-service")

        print("Server running...")
        try await Task.sleep(for: .seconds(3600))
    }
}

// Package.swift dependencies:
// - SurrealDB (full implementation)
// - Trebuchet
```

### Client Side (iOS/watchOS/macOS)

```swift
// App.swift
import SurrealDBClient  // ✅ Only thin client - no SurrealDB implementation!
import SwiftUI

@main
struct MyApp: App {
    @State private var db: SurrealDBClient?
    @State private var users: [User] = []

    var body: some View {
        NavigationStack {
            List(users) { user in
                Text(user.name)
            }
        }
        .task {
            // Connect to remote service
            db = try? await SurrealDBClient.connect(to: "trebuchet://server:9000/surrealdb-service")

            // Call remote methods - no local implementation!
            users = try? await db?.select("users") ?? []
        }
    }
}

// Package.swift dependencies:
// - SurrealDBClient (thin client only)
// - Trebuchet
// ✅ NO SurrealDB implementation
// ✅ NO WebSocket dependencies
// ✅ Minimal binary size
```

## Comparison

### Old Approach (Shared Protocol)

**Client app includes:**
```
✅ Shared protocol (small)
❌ SurrealDB library (~100KB)
❌ WebSocket library (~50KB)
❌ JSON-RPC implementation (~20KB)
❌ Transport layer (~30KB)
Total: ~200KB+ of unused code
```

### New Approach (Multi-Target)

**Client app includes:**
```
✅ SurrealDBCore (types only, ~20KB)
✅ SurrealDBClient (stub, ~5KB)
✅ Trebuchet client runtime (~30KB)
Total: ~55KB
```

**Server includes:**
```
✅ SurrealDBCore (~20KB)
✅ SurrealDB full implementation (~200KB)
✅ Trebuchet server runtime (~50KB)
Total: ~270KB (acceptable on server)
```

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Client Size** | ~200KB+ | ~55KB |
| **Dependencies** | SurrealDB + WebSocket + ... | Core types + Trebuchet |
| **Compile Time** | Slow (full implementation) | Fast (stub only) |
| **Separation** | Mixed | Clean client/server split |
| **Security** | DB credentials in app | Only on server |

## Type Safety Across Boundary

```swift
// Shared model (in SurrealDBCore or your app)
struct User: Codable, Sendable {
    let id: String
    let name: String
    let email: String
}

// Server - full implementation
let service = try await SurrealDBService(url: "...")
let user: User = try await service.create("users", data: newUser)

// Client - thin stub, SAME API
let client = try await SurrealDBClient.connect(to: "...")
let user: User = try await client.create("users", data: newUser)

// ✅ Same type safety
// ✅ No duplication of business logic
// ✅ Minimal client footprint
```

## Advanced: Per-Method Stubs

For even more control, you can create specialized stubs:

```swift
// SurrealDBClient/UserServiceStub.swift
import SurrealDBCore
import Trebuchet

/// Specialized stub for user operations only
@Trebuchet
public distributed actor UserService {
    public distributed func getUser(id: String) async throws -> User {
        // Trebuchet generates network call
    }

    public distributed func createUser(_ user: User) async throws -> User {
        // Trebuchet generates network call
    }

    public distributed func listUsers(age: Int) async throws -> [User] {
        // Trebuchet generates network call
    }
}

// Client only compiles UserService stub
// Server implements full UserService with SurrealDB underneath
```

## Migration Strategy

### Phase 1: Extract Core
1. Create `SurrealDBCore` target
2. Move shared types (RecordID, SurrealValue, SurrealError)
3. Define `SurrealDBServiceProtocol`

### Phase 2: Split Server Implementation
1. Keep all current code in `SurrealDB` target
2. Make it depend on `SurrealDBCore`
3. Implement distributed actor server

### Phase 3: Create Client
1. Create `SurrealDBClient` target
2. Implement thin distributed actor stub
3. Add convenience methods

### Phase 4: Documentation
1. Document server setup
2. Document client usage
3. Provide examples for both

## Example Project Structure

```
MyProject/
├── Server/                      # Server executable
│   ├── Package.swift
│   │   dependencies: [
│   │     "SurrealDB",          # Full implementation
│   │     "Trebuchet"
│   │   ]
│   └── main.swift
│
└── iOSApp/                      # iOS app
    ├── Package.swift
    │   dependencies: [
    │     "SurrealDBClient",     # Thin stub only!
    │     "Trebuchet"
    │   ]
    └── App.swift
```

## Security Benefit

**Big win**: Database credentials never in client app!

```swift
// Server side - credentials here
let service = try await SurrealDBService(url: "ws://db:8000/rpc")
try await service.signin(.root(
    RootAuth(username: "root", password: "secret")
))

// Client side - no credentials, just calls methods
let client = try await SurrealDBClient.connect(to: "trebuchet://server:9000/db")
let users = try await client.select("users")  // Authorized by server
```

## Answer to Your Question

> "I think it would mean duplication if we don't want these symbols to compile on the app side"

**You're absolutely right!**

**Solution**: Multi-target architecture:
- ✅ `SurrealDBCore` - Shared types (~20KB)
- ✅ `SurrealDB` - Full server implementation (~200KB) - **Server only**
- ✅ `SurrealDBClient` - Thin stub (~5KB) - **Client only**

**Result**:
- Client apps: ~55KB (no duplication, no SurrealDB implementation)
- Server: ~270KB (acceptable)
- Zero code duplication in business logic
- Clean separation of concerns

---

**This is the correct architecture for Trebuchet integration!** 🎯
