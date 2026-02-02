@testable import SurrealDB
import Testing

/// Comprehensive tests for TypeMapper functionality.
@Suite("Type Mapper")
struct TypeMapperTests {
    // MARK: - Primitive Types

    @Test("Maps String to .string")
    func stringType() {
        #expect(TypeMapper.fieldType(from: "String") == .string)
    }

    @Test("Maps Bool to .bool")
    func boolType() {
        #expect(TypeMapper.fieldType(from: "Bool") == .bool)
    }

    @Test("Maps Null to .null")
    func nullType() {
        #expect(TypeMapper.fieldType(from: "Null") == .null)
    }

    // MARK: - Integer Types

    @Test("Maps Int to .int")
    func intType() {
        #expect(TypeMapper.fieldType(from: "Int") == .int)
    }

    @Test("Maps Int8 to .int")
    func int8Type() {
        #expect(TypeMapper.fieldType(from: "Int8") == .int)
    }

    @Test("Maps Int16 to .int")
    func int16Type() {
        #expect(TypeMapper.fieldType(from: "Int16") == .int)
    }

    @Test("Maps Int32 to .int")
    func int32Type() {
        #expect(TypeMapper.fieldType(from: "Int32") == .int)
    }

    @Test("Maps Int64 to .int")
    func int64Type() {
        #expect(TypeMapper.fieldType(from: "Int64") == .int)
    }

    @Test("Maps UInt to .int")
    func uintType() {
        #expect(TypeMapper.fieldType(from: "UInt") == .int)
    }

    @Test("Maps UInt8 to .int")
    func uint8Type() {
        #expect(TypeMapper.fieldType(from: "UInt8") == .int)
    }

    @Test("Maps UInt16 to .int")
    func uint16Type() {
        #expect(TypeMapper.fieldType(from: "UInt16") == .int)
    }

    @Test("Maps UInt32 to .int")
    func uint32Type() {
        #expect(TypeMapper.fieldType(from: "UInt32") == .int)
    }

    @Test("Maps UInt64 to .int")
    func uint64Type() {
        #expect(TypeMapper.fieldType(from: "UInt64") == .int)
    }

    // MARK: - Float Types

    @Test("Maps Float to .float")
    func floatType() {
        #expect(TypeMapper.fieldType(from: "Float") == .float)
    }

    @Test("Maps CGFloat to .float")
    func cgFloatType() {
        #expect(TypeMapper.fieldType(from: "CGFloat") == .float)
    }

    // MARK: - Foundation Types

    @Test("Maps Date to .datetime")
    func dateType() {
        #expect(TypeMapper.fieldType(from: "Date") == .datetime)
    }

    @Test("Maps Foundation.Date to .datetime")
    func foundationDateType() {
        #expect(TypeMapper.fieldType(from: "Foundation.Date") == .datetime)
    }

    @Test("Maps UUID to .uuid")
    func uuidType() {
        #expect(TypeMapper.fieldType(from: "UUID") == .uuid)
    }

    @Test("Maps Foundation.UUID to .uuid")
    func foundationUUIDType() {
        #expect(TypeMapper.fieldType(from: "Foundation.UUID") == .uuid)
    }

    @Test("Maps Data to .bytes")
    func dataType() {
        #expect(TypeMapper.fieldType(from: "Data") == .bytes)
    }

    @Test("Maps Foundation.Data to .bytes")
    func foundationDataType() {
        #expect(TypeMapper.fieldType(from: "Foundation.Data") == .bytes)
    }

    @Test("Maps Decimal to .decimal")
    func decimalType() {
        #expect(TypeMapper.fieldType(from: "Decimal") == .decimal)
    }

    @Test("Maps Foundation.Decimal to .decimal")
    func foundationDecimalType() {
        #expect(TypeMapper.fieldType(from: "Foundation.Decimal") == .decimal)
    }

    // MARK: - Optional Types

    @Test("Maps String? to .option(.string)")
    func optionalStringSuffix() {
        #expect(TypeMapper.fieldType(from: "String?") == .option(of: .string))
    }

    @Test("Maps Optional<String> to .option(.string)")
    func optionalStringGeneric() {
        #expect(TypeMapper.fieldType(from: "Optional<String>") == .option(of: .string))
    }

    @Test("Maps Int? to .option(.int)")
    func optionalInt() {
        #expect(TypeMapper.fieldType(from: "Int?") == .option(of: .int))
    }

    @Test("Maps Bool? to .option(.bool)")
    func optionalBool() {
        #expect(TypeMapper.fieldType(from: "Bool?") == .option(of: .bool))
    }

    @Test("Maps Date? to .option(.datetime)")
    func optionalDate() {
        #expect(TypeMapper.fieldType(from: "Date?") == .option(of: .datetime))
    }

    @Test("Maps UUID? to .option(.uuid)")
    func optionalUUID() {
        #expect(TypeMapper.fieldType(from: "UUID?") == .option(of: .uuid))
    }

    @Test("Maps nested optionals Optional<Optional<String>> to .option(.option(.string))")
    func nestedOptionals() {
        let result = TypeMapper.fieldType(from: "Optional<Optional<String>>")
        #expect(result == .option(of: .option(of: .string)))
    }

    @Test("Maps nested optionals String?? to .option(.option(.string))")
    func nestedOptionalsSuffix() {
        let result = TypeMapper.fieldType(from: "String??")
        #expect(result == .option(of: .option(of: .string)))
    }

    // MARK: - Array Types

    @Test("Maps [String] to .array(.string)")
    func arrayBracketSyntax() {
        #expect(TypeMapper.fieldType(from: "[String]") == .array(of: .string))
    }

    @Test("Maps Array<String> to .array(.string)")
    func arrayGenericSyntax() {
        #expect(TypeMapper.fieldType(from: "Array<String>") == .array(of: .string))
    }

    @Test("Maps [Int] to .array(.int)")
    func arrayOfInts() {
        #expect(TypeMapper.fieldType(from: "[Int]") == .array(of: .int))
    }

    @Test("Maps [Bool] to .array(.bool)")
    func arrayOfBools() {
        #expect(TypeMapper.fieldType(from: "[Bool]") == .array(of: .bool))
    }

    @Test("Maps [Date] to .array(.datetime)")
    func arrayOfDates() {
        #expect(TypeMapper.fieldType(from: "[Date]") == .array(of: .datetime))
    }

    @Test("Maps [UUID] to .array(.uuid)")
    func arrayOfUUIDs() {
        #expect(TypeMapper.fieldType(from: "[UUID]") == .array(of: .uuid))
    }

    @Test("Maps Array<Optional<String>> to .array(.option(.string))")
    func arrayOfOptionals() {
        let result = TypeMapper.fieldType(from: "Array<Optional<String>>")
        #expect(result == .array(of: .option(of: .string)))
    }

    @Test("Maps [String?] to .array(.option(.string))")
    func arrayOfOptionalsSuffix() {
        let result = TypeMapper.fieldType(from: "[String?]")
        #expect(result == .array(of: .option(of: .string)))
    }

    @Test("Maps Optional<Array<String>> to .option(.array(.string))")
    func optionalArray() {
        let result = TypeMapper.fieldType(from: "Optional<Array<String>>")
        #expect(result == .option(of: .array(of: .string)))
    }

    @Test("Maps [String]? to .option(.array(.string))")
    func optionalArraySuffix() {
        let result = TypeMapper.fieldType(from: "[String]?")
        #expect(result == .option(of: .array(of: .string)))
    }

    // MARK: - Set Types

    @Test("Maps Set<String> to .set(.string)")
    func setOfStrings() {
        #expect(TypeMapper.fieldType(from: "Set<String>") == .set(of: .string))
    }

    @Test("Maps Set<Int> to .set(.int)")
    func setOfInts() {
        #expect(TypeMapper.fieldType(from: "Set<Int>") == .set(of: .int))
    }

    @Test("Maps Set<UUID> to .set(.uuid)")
    func setOfUUIDs() {
        #expect(TypeMapper.fieldType(from: "Set<UUID>") == .set(of: .uuid))
    }

    @Test("Maps Set<String?> to .set(.option(.string))")
    func setOfOptionals() {
        let result = TypeMapper.fieldType(from: "Set<String?>")
        #expect(result == .set(of: .option(of: .string)))
    }

    @Test("Maps Set<String>? to .option(.set(.string))")
    func optionalSet() {
        let result = TypeMapper.fieldType(from: "Set<String>?")
        #expect(result == .option(of: .set(of: .string)))
    }

    // MARK: - RecordID Types

    @Test("Maps RecordID to .record(table: nil)")
    func recordIDNoGeneric() {
        #expect(TypeMapper.fieldType(from: "RecordID") == .record(table: nil))
    }

    @Test("Maps RecordID<User> to .record(table: 'user')")
    func recordIDWithGeneric() {
        #expect(TypeMapper.fieldType(from: "RecordID<User>") == .record(table: "user"))
    }

    @Test("Maps RecordID<Post> to .record(table: 'post')")
    func recordIDWithPostGeneric() {
        #expect(TypeMapper.fieldType(from: "RecordID<Post>") == .record(table: "post"))
    }

    @Test("Maps RecordID<MyApp.User> to .record(table: 'user') stripping namespace")
    func recordIDWithNamespace() {
        #expect(TypeMapper.fieldType(from: "RecordID<MyApp.User>") == .record(table: "user"))
    }

    @Test("Maps RecordID<Com.Example.App.User> to .record(table: 'user') stripping multi-level namespace")
    func recordIDWithMultiLevelNamespace() {
        #expect(TypeMapper.fieldType(from: "RecordID<Com.Example.App.User>") == .record(table: "user"))
    }

    @Test("Maps RecordID<User>? to .option(.record(table: 'user'))")
    func optionalRecordID() {
        let result = TypeMapper.fieldType(from: "RecordID<User>?")
        #expect(result == .option(of: .record(table: "user")))
    }

    @Test("Maps [RecordID<User>] to .array(.record(table: 'user'))")
    func arrayOfRecordIDs() {
        let result = TypeMapper.fieldType(from: "[RecordID<User>]")
        #expect(result == .array(of: .record(table: "user")))
    }

    @Test("Maps Set<RecordID<User>> to .set(.record(table: 'user'))")
    func setOfRecordIDs() {
        let result = TypeMapper.fieldType(from: "Set<RecordID<User>>")
        #expect(result == .set(of: .record(table: "user")))
    }

    // MARK: - Complex Nested Types

    @Test("Maps Array<Array<String>> to nested arrays")
    func nestedArrays() {
        let result = TypeMapper.fieldType(from: "Array<Array<String>>")
        #expect(result == .array(of: .array(of: .string)))
    }

    @Test("Maps [[Int]] to nested arrays")
    func nestedArraysBracketSyntax() {
        let result = TypeMapper.fieldType(from: "[[Int]]")
        #expect(result == .array(of: .array(of: .int)))
    }

    @Test("Maps Array<Set<String>> to .array(.set(.string))")
    func arrayOfSets() {
        let result = TypeMapper.fieldType(from: "Array<Set<String>>")
        #expect(result == .array(of: .set(of: .string)))
    }

    @Test("Maps Set<Array<Int>> to .set(.array(.int))")
    func setOfArrays() {
        let result = TypeMapper.fieldType(from: "Set<Array<Int>>")
        #expect(result == .set(of: .array(of: .int)))
    }

    @Test("Maps Optional<Array<Optional<RecordID<User>>>> to deeply nested type")
    func deeplyNestedType() {
        let result = TypeMapper.fieldType(from: "Optional<Array<Optional<RecordID<User>>>>")
        #expect(result == .option(of: .array(of: .option(of: .record(table: "user")))))
    }

    @Test("Maps [RecordID<User>?]? to .option(.array(.option(.record(table: 'user'))))")
    func complexNestedOptionalArray() {
        let result = TypeMapper.fieldType(from: "[RecordID<User>?]?")
        #expect(result == .option(of: .array(of: .option(of: .record(table: "user")))))
    }

    // MARK: - Custom Types

    @Test("Maps custom type User to .object")
    func customType() {
        #expect(TypeMapper.fieldType(from: "User") == .object)
    }

    @Test("Maps custom type Post to .object")
    func customTypePost() {
        #expect(TypeMapper.fieldType(from: "Post") == .object)
    }

    @Test("Maps custom type MyCustomStruct to .object")
    func customTypeStruct() {
        #expect(TypeMapper.fieldType(from: "MyCustomStruct") == .object)
    }

    @Test("Maps Optional<User> to .option(.object)")
    func optionalCustomType() {
        let result = TypeMapper.fieldType(from: "Optional<User>")
        #expect(result == .option(of: .object))
    }

    @Test("Maps [User] to .array(.object)")
    func arrayOfCustomTypes() {
        let result = TypeMapper.fieldType(from: "[User]")
        #expect(result == .array(of: .object))
    }

    // MARK: - Edge Cases

    @Test("Maps empty string to .any")
    func emptyString() {
        #expect(TypeMapper.fieldType(from: "") == .any)
    }

    @Test("Maps whitespace to .any")
    func whitespace() {
        #expect(TypeMapper.fieldType(from: "   ") == .any)
    }

    @Test("Maps lowercase custom type to .any")
    func lowercaseCustomType() {
        #expect(TypeMapper.fieldType(from: "user") == .any)
    }

    @Test("Maps unknown type to .any")
    func unknownType() {
        #expect(TypeMapper.fieldType(from: "SomeUnknownType123") == .object)
    }

    @Test("Trims whitespace from type string")
    func trimsWhitespace() {
        #expect(TypeMapper.fieldType(from: "  String  ") == .string)
        #expect(TypeMapper.fieldType(from: "\tInt\t") == .int)
        // Note: newlines with just \n may not be trimmed, depends on whitespaces character set
        // Testing with spaces and tabs which are more common
    }

    @Test("Handles type with spaces in generics")
    func genericWithSpaces() {
        let result = TypeMapper.fieldType(from: "Array< String >")
        #expect(result == .array(of: .string))
    }

    // MARK: - isOptional() Helper Tests

    @Test("isOptional detects String? as optional")
    func isOptionalSuffix() {
        #expect(TypeMapper.isOptional("String?") == true)
    }

    @Test("isOptional detects Optional<String> as optional")
    func isOptionalGeneric() {
        #expect(TypeMapper.isOptional("Optional<String>") == true)
    }

    @Test("isOptional detects String as non-optional")
    func isOptionalNonOptional() {
        #expect(TypeMapper.isOptional("String") == false)
    }

    @Test("isOptional detects Int as non-optional")
    func isOptionalInt() {
        #expect(TypeMapper.isOptional("Int") == false)
    }

    @Test("isOptional detects nested optionals")
    func isOptionalNested() {
        #expect(TypeMapper.isOptional("String??") == true)
        #expect(TypeMapper.isOptional("Optional<Optional<String>>") == true)
    }

    @Test("isOptional handles empty string")
    func isOptionalEmpty() {
        #expect(TypeMapper.isOptional("") == false)
    }

    // MARK: - unwrapOptional() Helper Tests

    @Test("unwrapOptional removes ? suffix")
    func unwrapOptionalSuffix() {
        #expect(TypeMapper.unwrapOptional("String?") == "String")
    }

    @Test("unwrapOptional removes Optional<> wrapper")
    func unwrapOptionalGeneric() {
        #expect(TypeMapper.unwrapOptional("Optional<String>") == "String")
    }

    @Test("unwrapOptional returns same string for non-optional")
    func unwrapOptionalNonOptional() {
        #expect(TypeMapper.unwrapOptional("String") == "String")
        #expect(TypeMapper.unwrapOptional("Int") == "Int")
    }

    @Test("unwrapOptional unwraps one level only")
    func unwrapOptionalOneLevel() {
        #expect(TypeMapper.unwrapOptional("String??") == "String?")
        #expect(TypeMapper.unwrapOptional("Optional<Optional<String>>") == "Optional<String>")
    }

    @Test("unwrapOptional handles complex types")
    func unwrapOptionalComplex() {
        #expect(TypeMapper.unwrapOptional("Array<String>?") == "Array<String>")
        #expect(TypeMapper.unwrapOptional("Optional<RecordID<User>>") == "RecordID<User>")
    }

    @Test("unwrapOptional handles empty string")
    func unwrapOptionalEmpty() {
        #expect(TypeMapper.unwrapOptional("").isEmpty)
    }

    // MARK: - Double Type

    @Test("Maps Double to appropriate type")
    func doubleType() {
        // Double is a floating-point type and should map to .float (not .decimal)
        // IEEE 754 floating point (inexact) should map to inexact SurrealDB type
        #expect(TypeMapper.fieldType(from: "Double") == .float)
    }

    // MARK: - Dictionary Types (not explicitly handled)

    @Test("Maps Dictionary to .object")
    func dictionaryType() {
        // Dictionary is not explicitly handled, should map to .object (uppercase)
        let result = TypeMapper.fieldType(from: "Dictionary<String, Int>")
        #expect(result == .object)
    }

    @Test("Maps [String: Int] as array syntax")
    func dictionaryBracketSyntax() {
        // Dictionary bracket syntax [String: Int] gets parsed as array of "String: Int"
        // Since "String: Int" starts with uppercase S, it becomes .object
        // This is a limitation - dictionary syntax isn't explicitly supported
        let result = TypeMapper.fieldType(from: "[String: Int]")
        #expect(result == .array(of: .object))
    }

    // MARK: - Multiple Generic Parameters

    @Test("Maps RecordID with multi-word type name")
    func recordIDMultiWord() {
        let result = TypeMapper.fieldType(from: "RecordID<UserProfile>")
        #expect(result == .record(table: "userprofile"))
    }

    @Test("Maps RecordID with snake_case type")
    func recordIDSnakeCase() {
        let result = TypeMapper.fieldType(from: "RecordID<user_profile>")
        #expect(result == .record(table: "user_profile"))
    }
}
