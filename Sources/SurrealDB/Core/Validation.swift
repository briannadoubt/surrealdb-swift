import Foundation

/// Validates SurrealDB identifiers (table names, field names).
public struct SurrealValidator: Sendable {
    /// Validates a table name.
    public static func validateTableName(_ name: String) throws {
        try validateIdentifier(name, context: "table name")
    }

    /// Validates a field name (supports dot notation for nested fields).
    public static func validateFieldName(_ name: String) throws {
        if name == "*" { return } // Special case for SELECT *

        // Check each component separated by dots
        let components = name.split(separator: ".")
        for component in components {
            try validateIdentifier(String(component), context: "field name")
        }
    }

    /// Validates a generic identifier.
    private static func validateIdentifier(_ identifier: String, context: String) throws {
        guard !identifier.isEmpty else {
            throw SurrealError.invalidQuery("Empty \(context)")
        }

        // Check for backtick-quoted identifiers
        if identifier.hasPrefix("`") && identifier.hasSuffix("`") {
            // Backtick-quoted identifiers allow any character except backtick
            let inner = identifier.dropFirst().dropLast()
            guard !inner.contains("`") else {
                throw SurrealError.invalidQuery(
                    "Invalid \(context): '\(identifier)'. Backtick-quoted identifiers cannot contain unescaped backticks."
                )
            }
            return
        }

        // Unquoted identifiers: alphanumeric, underscore, must start with letter/underscore
        let pattern = "^[a-zA-Z_][a-zA-Z0-9_]*$"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(identifier.startIndex..., in: identifier)

        guard regex.firstMatch(in: identifier, range: range) != nil else {
            throw SurrealError.invalidQuery(
                "Invalid \(context): '\(identifier)'. Must be alphanumeric with underscores, " +
                "start with letter/underscore, or be backtick-quoted like `\(identifier)`."
            )
        }
    }
}
