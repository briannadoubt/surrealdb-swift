# Live Queries

Real-time database subscriptions with SurrealDB live queries.

## Overview

Live queries allow you to subscribe to changes in your database in real-time. When records are created, updated, or deleted, your application receives notifications immediately through a WebSocket connection.

> Important: Live queries require WebSocket transport. They are not available with HTTP transport.

## Creating a Live Query

Subscribe to changes on a table:

```swift
let (queryId, stream) = try await db.live("users")

Task {
    for await notification in stream {
        switch notification.action {
        case .create:
            print("New record:", notification.result)
        case .update:
            print("Updated record:", notification.result)
        case .delete:
            print("Deleted record:", notification.result)
        case .close:
            print("Query closed")
            break
        }
    }
}
```

## Live Query Actions

Each notification includes an action type:

- `CREATE` - A new record was added
- `UPDATE` - An existing record was modified
- `DELETE` - A record was removed
- `CLOSE` - The live query was closed by the server

## Using Diffs

Request only the changed fields instead of full records:

```swift
let (queryId, stream) = try await db.live("users", diff: true)

for await notification in stream {
    // notification.result contains only changed fields
    print("Changed fields:", notification.result)
}
```

## Killing a Live Query

Stop receiving notifications by killing the query:

```swift
try await db.kill(queryId)
```

The stream will automatically close when killed.

## SwiftUI Integration

### Observable Live Query

Create an observable object for SwiftUI:

```swift
import SwiftUI
import SurrealDB

@MainActor
@Observable
class UserStore {
    private let db: SurrealDB
    private var liveQueryTask: Task<Void, Never>?
    private var queryId: String?

    var users: [User] = []

    init(db: SurrealDB) {
        self.db = db
    }

    func startLiveQuery() async throws {
        let (id, stream) = try await db.live("users")
        queryId = id

        liveQueryTask = Task {
            for await notification in stream {
                await handleNotification(notification)
            }
        }
    }

    func stopLiveQuery() async throws {
        liveQueryTask?.cancel()
        liveQueryTask = nil

        if let id = queryId {
            try await db.kill(id)
            queryId = nil
        }
    }

    private func handleNotification(_ notification: LiveQueryNotification) async {
        do {
            let user: User = try notification.result.decode()

            switch notification.action {
            case .create:
                users.append(user)
            case .update:
                if let index = users.firstIndex(where: { $0.id == user.id }) {
                    users[index] = user
                }
            case .delete:
                users.removeAll { $0.id == user.id }
            case .close:
                break
            }
        } catch {
            print("Failed to decode user:", error)
        }
    }

    deinit {
        liveQueryTask?.cancel()
    }
}
```

### Using in SwiftUI

```swift
struct UserListView: View {
    @State private var store: UserStore

    init(db: SurrealDB) {
        _store = State(initialValue: UserStore(db: db))
    }

    var body: some View {
        List(store.users) { user in
            Text(user.name)
        }
        .task {
            try? await store.startLiveQuery()
        }
        .onDisappear {
            Task {
                try? await store.stopLiveQuery()
            }
        }
    }
}
```

## Multiple Live Queries

You can have multiple active live queries:

```swift
// Watch users
let (usersId, usersStream) = try await db.live("users")

// Watch posts
let (postsId, postsStream) = try await db.live("posts")

// Process both streams
async let users: Void = processUsers(usersStream)
async let posts: Void = processPosts(postsStream)

_ = try await (users, posts)
```

## Error Handling

Handle errors in live query streams:

```swift
do {
    let (queryId, stream) = try await db.live("users")

    for await notification in stream {
        do {
            let user: User = try notification.result.decode()
            // Handle user update
        } catch {
            print("Failed to decode notification:", error)
            // Continue processing other notifications
        }
    }
} catch let error as SurrealError {
    switch error {
    case .unsupportedOperation:
        print("Live queries require WebSocket transport")
    case .connectionError:
        print("Connection lost")
    default:
        print("Error:", error)
    }
}
```

## Best Practices

1. **Clean up queries** - Always kill live queries when done to free server resources

2. **Handle reconnection** - Implement reconnection logic for WebSocket disconnects

3. **Limit scope** - Use specific table queries rather than watching entire databases

4. **Process asynchronously** - Don't block the notification stream with heavy processing

5. **Type safety** - Decode notifications to typed models for compile-time safety

## Performance Considerations

- Live queries maintain an open WebSocket connection
- Each active query uses server resources
- Use `diff: true` to reduce bandwidth for large records
- Consider debouncing rapid updates in the UI
- Kill queries that are no longer needed

## Example: Real-time Dashboard

```swift
import SwiftUI
import SurrealDB

@MainActor
@Observable
class Dashboard {
    private let db: SurrealDB
    private var queries: [String: Task<Void, Never>] = [:]

    var metrics: Metrics?
    var alerts: [Alert] = []
    var activeUsers: Int = 0

    init(db: SurrealDB) {
        self.db = db
    }

    func start() async throws {
        try await startMetricsQuery()
        try await startAlertsQuery()
        try await startUsersQuery()
    }

    func stop() async throws {
        for (queryId, task) in queries {
            task.cancel()
            try await db.kill(queryId)
        }
        queries.removeAll()
    }

    private func startMetricsQuery() async throws {
        let (id, stream) = try await db.live("metrics")

        queries[id] = Task {
            for await notification in stream {
                if let metrics: Metrics = try? notification.result.decode() {
                    self.metrics = metrics
                }
            }
        }
    }

    private func startAlertsQuery() async throws {
        let (id, stream) = try await db.live("alerts")

        queries[id] = Task {
            for await notification in stream {
                guard let alert: Alert = try? notification.result.decode() else {
                    continue
                }

                switch notification.action {
                case .create:
                    alerts.append(alert)
                case .delete:
                    alerts.removeAll { $0.id == alert.id }
                default:
                    break
                }
            }
        }
    }

    private func startUsersQuery() async throws {
        let (id, stream) = try await db.live("active_sessions")

        queries[id] = Task {
            for await notification in stream {
                // Count active sessions
                activeUsers = try await db.query(
                    "SELECT count() FROM active_sessions GROUP ALL"
                ).first?["count"]?.decode() ?? 0
            }
        }
    }
}
```
