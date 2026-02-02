import Foundation

/// Validates SurrealDB identifiers (table names, field names).
public struct SurrealValidator: Sendable {
    /// Regex pattern for valid unquoted identifiers.
    /// Matches: alphanumeric with underscores, must start with letter/underscore.
    private static let identifierRegex: NSRegularExpression = {
        // This pattern is a compile-time constant and will never fail
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^[a-zA-Z_][a-zA-Z0-9_]*$")
    }()

    /// Reserved keywords that cannot be used as unquoted identifiers.
    /// These are SurrealDB SQL keywords that would cause parsing ambiguities.
    private static let reservedKeywords: Set<String> = [
        // Query commands
        "select", "from", "where", "insert", "update", "delete", "create",
        "relate", "define", "remove", "info", "begin", "commit", "cancel",
        // Schema definition
        "table", "field", "index", "type", "relation", "event", "function",
        "namespace", "database", "scope", "token", "analyzer", "user",
        // Data types
        "string", "int", "float", "bool", "datetime", "duration", "decimal",
        "number", "object", "array", "record", "geometry", "bytes", "uuid",
        // Control flow
        "if", "else", "then", "end", "for", "in", "let", "return", "throw",
        // Logical operators
        "and", "or", "not", "is", "contains", "containsall", "containsany",
        "containsnone", "inside", "allinside", "anyinside", "noneinside",
        "outside", "intersects",
        // Literals
        "true", "false", "null", "none", "void",
        // Keywords
        "as", "at", "by", "default", "value", "assert", "permissions",
        "full", "readonly", "schemafull", "schemaless", "unique", "drop",
        "on", "to", "set", "unset", "content", "merge", "patch", "diff",
        "split", "group", "order", "limit", "start", "fetch", "timeout",
        "parallel", "explain", "use", "live", "kill", "with", "noindex",
        "only", "when", "optional", "flexible"
    ]

    /// Validates a table name.
    public static func validateTableName(_ name: String) throws(SurrealError) {
        try validateIdentifier(name, context: "table name")
    }

    /// Validates a field name (supports dot notation for nested fields).
    public static func validateFieldName(_ name: String) throws(SurrealError) {
        if name == "*" { return } // Special case for SELECT *

        guard !name.isEmpty else {
            throw SurrealError.invalidQuery("Empty field name")
        }

        // Check each component separated by dots
        let components = name.split(separator: ".")
        guard !components.isEmpty else {
            throw SurrealError.invalidQuery("Invalid field name")
        }

        for component in components {
            try validateIdentifier(String(component), context: "field name")
        }
    }

    /// Validates an index name.
    public static func validateIndexName(_ name: String) throws(SurrealError) {
        try validateIdentifier(name, context: "index name")
    }

    /// Validates a list of field names for an index.
    ///
    /// - Parameter fields: The field names to validate.
    /// - Throws: `SurrealError.validationError` if any field name is invalid or the list is empty.
    public static func validateIndexFields(_ fields: [String]) throws(SurrealError) {
        guard !fields.isEmpty else {
            throw SurrealError.validationError("Index must have at least one field")
        }

        for field in fields {
            try validateFieldName(field)
        }
    }

    /// Validates a generic identifier.
    private static func validateIdentifier(_ identifier: String, context: String) throws(SurrealError) {
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

        // Validate unquoted identifiers using cached regex
        let range = NSRange(identifier.startIndex..., in: identifier)

        guard identifierRegex.firstMatch(in: identifier, range: range) != nil else {
            throw SurrealError.invalidQuery(
                "Invalid \(context): '\(identifier)'. Must be alphanumeric with underscores, " +
                "start with letter/underscore, or be backtick-quoted like `\(identifier)`."
            )
        }

        // Check for reserved keywords (case-insensitive)
        if reservedKeywords.contains(identifier.lowercased()) {
            throw SurrealError.invalidQuery(
                "'\(identifier)' is a reserved keyword and cannot be used as a \(context). " +
                "Use backtick-quoted identifier like `\(identifier)` instead."
            )
        }
    }
}
