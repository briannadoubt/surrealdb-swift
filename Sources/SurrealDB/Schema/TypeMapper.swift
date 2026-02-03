import Foundation

// MARK: - Type Mapper

/// Maps Swift types to SurrealDB FieldType.
/// This is used by macros to generate schema descriptors.
public enum TypeMapper {
    /// Map a Swift type string to a FieldType
    public static func fieldType(from swiftType: String) -> FieldType {
        // Remove whitespace
        let type = swiftType.trimmingCharacters(in: .whitespaces)

        // Handle Optional<T> and T?
        if let innerType = extractOptionalType(from: type) {
            return .option(of: fieldType(from: innerType))
        }

        // Handle collection types
        if let collectionType = mapCollectionType(type) {
            return collectionType
        }

        // Handle RecordID and RecordID<T>
        if let recordType = mapRecordIDType(type) {
            return recordType
        }

        // Handle Foundation types
        if let foundationType = mapFoundationType(type) {
            return foundationType
        }

        // Handle primitive types
        if let primitiveType = mapPrimitiveType(type) {
            return primitiveType
        }

        // Handle custom types as objects
        if type.first?.isUppercase == true {
            return .object
        }

        // Default to any
        return .any
    }

    /// Map collection types (Array, Set)
    private static func mapCollectionType(_ type: String) -> FieldType? {
        // Handle Array<T> and [T]
        if let elementType = extractArrayType(from: type) {
            return .array(of: fieldType(from: elementType))
        }

        // Handle Set<T>
        if let elementType = extractSetType(from: type) {
            return .set(of: fieldType(from: elementType))
        }

        return nil
    }

    /// Map RecordID types
    private static func mapRecordIDType(_ type: String) -> FieldType? {
        guard type.hasPrefix("RecordID") else { return nil }

        if let table = extractGenericParameter(from: type) {
            // Strip namespace prefix (e.g., MyApp.User -> User)
            let tableName = table.split(separator: ".").last.map(String.init)?.lowercased() ?? table.lowercased()
            return .record(table: tableName)
        }
        return .record(table: nil)
    }

    /// Map Foundation types (Date, UUID, Data, Decimal)
    private static func mapFoundationType(_ type: String) -> FieldType? {
        if type == "Date" || type == "Foundation.Date" {
            return .datetime
        }

        if type == "UUID" || type == "Foundation.UUID" {
            return .uuid
        }

        if type == "Data" || type == "Foundation.Data" {
            return .bytes
        }

        // Decimal types (precise)
        if type == "Decimal" || type == "Foundation.Decimal" {
            return .decimal
        }

        return nil
    }

    /// Map primitive Swift types
    private static func mapPrimitiveType(_ type: String) -> FieldType? {
        switch type {
        case "String":
            return .string
        case "Int", "Int8", "Int16", "Int32", "Int64":
            return .int
        case "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return .int
        case "Float", "Double", "CGFloat":
            return .float
        case "Bool":
            return .bool
        case "Null":
            return .null
        default:
            return nil
        }
    }

    /// Extract the inner type from Optional<T> or T?
    private static func extractOptionalType(from type: String) -> String? {
        // Handle T? syntax
        if type.hasSuffix("?") {
            return String(type.dropLast())
        }

        // Handle Optional<T> syntax
        if type.hasPrefix("Optional<"), type.hasSuffix(">") {
            let start = type.index(type.startIndex, offsetBy: 9) // "Optional<".count
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }

        return nil
    }

    /// Extract the element type from Array<T> or [T]
    private static func extractArrayType(from type: String) -> String? {
        // Handle [T] syntax
        if type.hasPrefix("["), type.hasSuffix("]") {
            let start = type.index(after: type.startIndex)
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }

        // Handle Array<T> syntax
        if type.hasPrefix("Array<"), type.hasSuffix(">") {
            let start = type.index(type.startIndex, offsetBy: 6) // "Array<".count
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }

        return nil
    }

    /// Extract the element type from Set<T>
    private static func extractSetType(from type: String) -> String? {
        if type.hasPrefix("Set<"), type.hasSuffix(">") {
            let start = type.index(type.startIndex, offsetBy: 4) // "Set<".count
            let end = type.index(before: type.endIndex)
            return String(type[start..<end])
        }
        return nil
    }

    /// Extract the generic parameter from a type like RecordID<User>
    private static func extractGenericParameter(from type: String) -> String? {
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

    /// Check if a type is optional
    public static func isOptional(_ type: String) -> Bool {
        return type.hasSuffix("?") || type.hasPrefix("Optional<")
    }

    /// Remove optional wrapper from a type string
    public static func unwrapOptional(_ type: String) -> String {
        if let inner = extractOptionalType(from: type) {
            return inner
        }
        return type
    }
}
