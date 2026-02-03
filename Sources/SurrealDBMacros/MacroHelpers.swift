import SwiftSyntax

// MARK: - Type Mapper

/// Type mapper utility for macro expansion
///
/// This enum provides utilities for converting Swift type strings to SurrealDB field types.
/// It's shared between SurrealMacro and SurrealEdgeMacro to avoid code duplication.
enum TypeMapper {
    static func isOptional(_ type: String) -> Bool {
        return type.hasSuffix("?") || type.hasPrefix("Optional<")
    }

    static func fieldType(from swiftType: String) -> String {
        // Trim whitespace manually since Foundation is not available in macro context
        let type = swiftType.trimmingWhitespace()

        // Handle Optional<T> and T?
        if isOptional(type) {
            let innerType = unwrapOptional(type)
            return ".option(of: \(fieldType(from: innerType)))"
        }

        // Handle Array<T> and [T]
        if let elementType = extractArrayType(from: type) {
            return ".array(of: \(fieldType(from: elementType)))"
        }

        // Handle Set<T>
        if let elementType = extractSetType(from: type) {
            return ".set(of: \(fieldType(from: elementType)))"
        }

        // Handle RecordID
        if type.hasPrefix("RecordID") {
            if let table = extractGenericParameter(from: type) {
                // Strip namespace prefix (e.g., MyApp.User -> User)
                let tableName = table.split(separator: ".").last.map(String.init)?.lowercased() ?? table.lowercased()
                return ".record(table: \"\(tableName)\")"
            }
            return ".record(table: nil)"
        }

        // Handle Date and Foundation types
        if type == "Date" || type == "Foundation.Date" {
            return ".datetime"
        }

        if type == "UUID" || type == "Foundation.UUID" {
            return ".uuid"
        }

        if type == "Data" || type == "Foundation.Data" {
            return ".bytes"
        }

        // Decimal types (precise)
        if type == "Decimal" || type == "Foundation.Decimal" {
            return ".decimal"
        }

        // Handle primitive types
        switch type {
        case "String":
            return ".string"
        case "Int", "Int8", "Int16", "Int32", "Int64":
            return ".int"
        case "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return ".int"
        case "Float", "Double", "CGFloat":
            return ".float"
        case "Bool":
            return ".bool"
        default:
            break
        }

        // Custom types default to object
        return ".object"
    }

    static func unwrapOptional(_ type: String) -> String {
        if type.hasSuffix("?") {
            return String(type.dropLast())
        }
        if type.hasPrefix("Optional<"), type.hasSuffix(">") {
            let start = type.index(type.startIndex, offsetBy: 9)
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }
        return type
    }

    static func extractArrayType(from type: String) -> String? {
        if type.hasPrefix("["), type.hasSuffix("]") {
            let start = type.index(after: type.startIndex)
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }
        if type.hasPrefix("Array<"), type.hasSuffix(">") {
            let start = type.index(type.startIndex, offsetBy: 6)
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }
        return nil
    }

    static func extractSetType(from type: String) -> String? {
        if type.hasPrefix("Set<"), type.hasSuffix(">") {
            let start = type.index(type.startIndex, offsetBy: 4)
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }
        return nil
    }

    static func extractGenericParameter(from type: String) -> String? {
        guard let start = type.firstIndex(of: "<") else {
            return nil
        }

        var depth = 0
        var end = start

        for char in type[start...] {
            if char == "<" {
                depth += 1
            } else if char == ">" {
                depth -= 1
                if depth == 0 { break }
            }
            end = type.index(after: end)
        }

        guard depth == 0 else { return nil }

        let startIndex = type.index(after: start)
        return String(type[startIndex..<end])
    }
}
