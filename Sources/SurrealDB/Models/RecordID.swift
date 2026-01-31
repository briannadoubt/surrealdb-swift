import Foundation

/// A strongly-typed record identifier in the format `table:id`.
///
/// Record IDs in SurrealDB follow the format `table:id` where the ID can be:
/// - A simple string or number: `users:john`
/// - A UUID enclosed in angle brackets: `users:⟨8c5ccf89-6c3c-4d11-8d7f-9ed5a3b95f6e⟩`
///
/// Example:
/// ```swift
/// let recordID = try RecordID(parsing: "users:john")
/// print(recordID.table) // "users"
/// print(recordID.id)    // "john"
/// print(recordID.toString()) // "users:john"
/// ```
public struct RecordID: Sendable, Hashable {
    /// The table name.
    public let table: String

    /// The record identifier within the table.
    public let id: String

    /// Creates a record ID from table and id components.
    public init(table: String, id: String) {
        self.table = table
        self.id = id
    }

    /// Parses a record ID string in the format `table:id`.
    ///
    /// - Parameter string: The record ID string to parse.
    /// - Throws: ``SurrealError/invalidRecordID(_:)`` if the format is invalid.
    public init(parsing string: String) throws(SurrealError) {
        // Split on the first colon
        guard let colonIndex = string.firstIndex(of: ":") else {
            throw SurrealError.invalidRecordID("Missing ':' separator in '\(string)'")
        }

        let table = String(string[..<colonIndex])
        let id = String(string[string.index(after: colonIndex)...])

        guard !table.isEmpty else {
            throw SurrealError.invalidRecordID("Table name cannot be empty in '\(string)'")
        }

        guard !id.isEmpty else {
            throw SurrealError.invalidRecordID("ID cannot be empty in '\(string)'")
        }

        self.table = table
        self.id = id
    }

    /// Returns the string representation in the format `table:id`.
    public func toString() -> String {
        "\(table):\(id)"
    }
}

// MARK: - Codable

extension RecordID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        try self.init(parsing: string)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toString())
    }
}

// MARK: - CustomStringConvertible

extension RecordID: CustomStringConvertible {
    public var description: String {
        toString()
    }
}

// MARK: - ExpressibleByStringLiteral

extension RecordID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        do {
            try self.init(parsing: value)
        } catch {
            fatalError(
                "Invalid RecordID literal '\(value)': \(error)\n" +
                "Note: String literals must be valid at compile time. " +
                "For runtime values, use RecordID(parsing:) which returns a Result."
            )
        }
    }
}
