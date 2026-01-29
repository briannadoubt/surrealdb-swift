import Foundation

/// Root-level authentication credentials.
public struct RootAuth: Sendable, Codable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Namespace-level authentication credentials.
public struct NamespaceAuth: Sendable, Codable {
    public let namespace: String
    public let username: String
    public let password: String

    public init(namespace: String, username: String, password: String) {
        self.namespace = namespace
        self.username = username
        self.password = password
    }

    enum CodingKeys: String, CodingKey {
        case namespace = "NS"
        case username
        case password
    }
}

/// Database-level authentication credentials.
public struct DatabaseAuth: Sendable, Codable {
    public let namespace: String
    public let database: String
    public let username: String
    public let password: String

    public init(namespace: String, database: String, username: String, password: String) {
        self.namespace = namespace
        self.database = database
        self.username = username
        self.password = password
    }

    enum CodingKeys: String, CodingKey {
        case namespace = "NS"
        case database = "DB"
        case username
        case password
    }
}

/// Record access authentication credentials.
public struct RecordAccessAuth: Sendable, Codable {
    public let namespace: String
    public let database: String
    public let access: String
    public let variables: [String: SurrealValue]?

    public init(namespace: String, database: String, access: String, variables: [String: SurrealValue]? = nil) {
        self.namespace = namespace
        self.database = database
        self.access = access
        self.variables = variables
    }

    enum CodingKeys: String, CodingKey {
        case namespace = "NS"
        case database = "DB"
        case access = "AC"
        case variables
    }
}

/// Authentication credentials for SurrealDB.
public enum Credentials: Sendable {
    case root(RootAuth)
    case namespace(NamespaceAuth)
    case database(DatabaseAuth)
    case recordAccess(RecordAccessAuth)

    /// Encodes the credentials to a SurrealValue for RPC calls.
    func toSurrealValue() throws -> SurrealValue {
        switch self {
        case .root(let auth):
            return try SurrealValue(from: auth)
        case .namespace(let auth):
            return try SurrealValue(from: auth)
        case .database(let auth):
            return try SurrealValue(from: auth)
        case .recordAccess(let auth):
            return try SurrealValue(from: auth)
        }
    }
}
