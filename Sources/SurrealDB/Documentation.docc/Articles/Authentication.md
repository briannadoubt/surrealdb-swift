# Authentication

Learn about different authentication strategies in SurrealDB.

## Overview

SurrealDB supports multiple authentication levels, from root-level system access to record-level user authentication. This guide covers all authentication methods available in the Swift client.

## Authentication Levels

### Root Authentication

Root authentication provides full system access:

```swift
try await db.signin(.root(
    RootAuth(username: "root", password: "root")
))
```

Use root authentication for:
- System administration
- Initial setup
- Testing and development

### Namespace Authentication

Namespace authentication scopes access to a specific namespace:

```swift
try await db.signin(.namespace(
    NamespaceAuth(
        namespace: "myapp",
        username: "admin",
        password: "secret"
    )
))
```

### Database Authentication

Database authentication scopes access to a specific database:

```swift
try await db.signin(.database(
    DatabaseAuth(
        namespace: "myapp",
        database: "prod",
        username: "dbuser",
        password: "secret"
    )
))
```

### Record Access (Scope) Authentication

Record access allows users to authenticate as database records:

```swift
// Sign in existing user
try await db.signin(.recordAccess(
    RecordAccessAuth(
        namespace: "myapp",
        database: "prod",
        access: "user",
        variables: [
            "email": .string("user@example.com"),
            "pass": .string("password123")
        ]
    )
))
```

## Signup

Create new record access users with signup:

```swift
let token = try await db.signup(
    RecordAccessAuth(
        namespace: "myapp",
        database: "prod",
        access: "user",
        variables: [
            "email": .string("newuser@example.com"),
            "pass": .string("password123"),
            "name": .string("New User")
        ]
    )
)
```

## Token-Based Authentication

After signing in, you receive a JWT token. You can save this token and use it later:

```swift
// Initial signin
let token = try await db.signin(.root(
    RootAuth(username: "root", password: "root")
))

// Save the token securely
UserDefaults.standard.set(token, forKey: "surrealdb_token")

// Later, authenticate with the saved token
if let savedToken = UserDefaults.standard.string(forKey: "surrealdb_token") {
    try await db.authenticate(token: savedToken)
}
```

## Session Management

### Checking Session Info

Get information about the current session:

```swift
let info = try await db.info()
print("Session info:", info)
```

### Invalidating Sessions

Sign out and invalidate the current session:

```swift
try await db.invalidate()
```

## Best Practices

1. **Use the minimum required access level** - Don't use root credentials when namespace or database auth will suffice

2. **Store tokens securely** - Use Keychain on Apple platforms to store JWT tokens

3. **Handle token expiration** - Implement token refresh logic or re-authenticate when tokens expire

4. **Validate on the server** - Always validate permissions on the server side with SurrealQL access rules

5. **Use HTTPS/WSS in production** - Never send credentials over unencrypted connections

## Example: Complete Auth Flow

```swift
import SurrealDB

actor AuthManager {
    private let db: SurrealDB

    init() throws {
        db = try SurrealDB(url: "wss://api.example.com/rpc")
    }

    func connect() async throws {
        try await db.connect()
    }

    func signIn(email: String, password: String) async throws -> String {
        let token = try await db.signin(.recordAccess(
            RecordAccessAuth(
                namespace: "myapp",
                database: "prod",
                access: "user",
                variables: [
                    "email": .string(email),
                    "pass": .string(password)
                ]
            )
        ))

        // Store token securely
        try saveToken(token)

        return token
    }

    func signUp(email: String, password: String, name: String) async throws -> String {
        let token = try await db.signup(
            RecordAccessAuth(
                namespace: "myapp",
                database: "prod",
                access: "user",
                variables: [
                    "email": .string(email),
                    "pass": .string(password),
                    "name": .string(name)
                ]
            )
        )

        try saveToken(token)
        return token
    }

    func restoreSession() async throws {
        guard let token = loadToken() else {
            throw AuthError.noSavedSession
        }

        try await db.authenticate(token: token)
    }

    func signOut() async throws {
        try await db.invalidate()
        clearToken()
    }

    private func saveToken(_ token: String) throws {
        // Use Keychain in production
        UserDefaults.standard.set(token, forKey: "auth_token")
    }

    private func loadToken() -> String? {
        UserDefaults.standard.string(forKey: "auth_token")
    }

    private func clearToken() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
}

enum AuthError: Error {
    case noSavedSession
}
```
