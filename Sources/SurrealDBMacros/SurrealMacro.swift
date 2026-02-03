import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The @Surreal macro for SurrealDB models.
///
/// This macro:
/// - Adds `id: RecordID? = nil` if not present
/// - Generates `static let tableName: String`
/// - Generates `static let _schemaDescriptor: SchemaDescriptor`
/// - Adds conformance to: SurrealModel, Codable, Sendable, HasSchemaDescriptor
public struct SurrealMacro: MemberMacro, ExtensionMacro {
    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Ensure this is a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: node,
                    message: MacroError.onlyApplicableToStruct
                )
            ])
        }

        let typeName = structDecl.name.text
        let tableName = extractTableName(from: node) ?? typeName.lowercased()

        var members: [DeclSyntax] = []

        // Check if id property already exists
        let hasIdProperty = structDecl.memberBlock.members.contains { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                return false
            }
            return variable.bindings.contains { binding in
                binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "id"
            }
        }

        // Add id property if not present
        if !hasIdProperty {
            members.append(
                """
                public var id: RecordID? = nil
                """
            )
        }

        // Generate tableName static property
        members.append(
            """
            public static let tableName: String = "\(raw: tableName)"
            """
        )

        // Generate _schemaDescriptor
        let fields = try extractFields(from: structDecl, context: context)
        let schemaDescriptor = generateSchemaDescriptor(
            tableName: tableName,
            fields: fields
        )

        members.append(schemaDescriptor)

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Add conformances (Sendable is auto-synthesized for simple value types)
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): SurrealModel, Codable, HasSchemaDescriptor {}
            """
        )

        return [extensionDecl]
    }

    // MARK: - Helper Methods

    /// Extract table name from macro attribute
    private static func extractTableName(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments,
              case .argumentList(let list) = arguments else {
            return nil
        }

        // Look for tableName argument
        for argument in list {
            if let label = argument.label?.text, label == "tableName",
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first,
               case .stringSegment(let text) = segment {
                return text.content.text
            }
        }

        return nil
    }

    /// Extract fields from struct declaration
    private static func extractFields(
        from structDecl: StructDeclSyntax,
        context: some MacroExpansionContext
    ) throws -> [FieldInfo] {
        var fields: [FieldInfo] = []

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            // Skip computed properties
            let isComputed = variable.bindings.contains { binding in
                binding.accessorBlock != nil
            }

            for binding in variable.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      let typeAnnotation = binding.typeAnnotation else {
                    continue
                }

                let fieldName = pattern.identifier.text
                let typeString = typeAnnotation.type.trimmedDescription

                // Check for property wrappers
                let attributes = variable.attributes
                let hasIndexWrapper = hasAttribute(named: "Index", in: attributes)
                let hasComputedWrapper = hasAttribute(named: "Computed", in: attributes)
                let hasRelationWrapper = hasAttribute(named: "Relation", in: attributes)

                // Skip @Relation and computed properties
                if hasRelationWrapper || isComputed {
                    continue
                }

                // Extract index type if present
                var indexType: String?
                if hasIndexWrapper {
                    indexType = extractIndexType(from: attributes)
                }

                let field = FieldInfo(
                    name: fieldName,
                    typeString: typeString,
                    isOptional: TypeMapper.isOptional(typeString),
                    hasIndex: hasIndexWrapper,
                    indexType: indexType,
                    isComputed: hasComputedWrapper,
                    isRelation: hasRelationWrapper
                )

                fields.append(field)
            }
        }

        return fields
    }

    /// Check if attributes contain a specific attribute name
    private static func hasAttribute(named name: String, in attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            if case .attribute(let attr) = attribute,
               let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
               identifierType.name.text == name {
                return true
            }
        }
        return false
    }

    /// Extract index type from @Index attribute
    private static func extractIndexType(from attributes: AttributeListSyntax) -> String? {
        for attribute in attributes {
            if case .attribute(let attr) = attribute,
               let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
               identifierType.name.text == "Index",
               let arguments = attr.arguments,
               case .argumentList(let list) = arguments {
                // Look for type: parameter
                for argument in list {
                    if let label = argument.label?.text, label == "type",
                       let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        return memberAccess.declName.baseName.text
                    }
                }
            }
        }
        return nil
    }

    /// Generate schema descriptor declaration
    private static func generateSchemaDescriptor(
        tableName: String,
        fields: [FieldInfo]
    ) -> DeclSyntax {
        var fieldDescriptors: [String] = []

        for field in fields {
            // Call TypeMapper.fieldType during macro expansion and serialize the result to Swift code
            let fieldTypeString = TypeMapper.fieldType(from: field.typeString)
            let isOptional = field.isOptional ? "true" : "false"
            let hasIndex = field.hasIndex ? "true" : "false"

            var indexTypeParam = "nil"
            if let indexType = field.indexType {
                indexTypeParam = ".\(indexType.lowercased())"
            }

            let isComputed = field.isComputed ? "true" : "false"
            let isRelation = field.isRelation ? "true" : "false"

            let descriptor = """
            FieldDescriptor(
                name: "\(field.name)",
                type: \(fieldTypeString),
                isOptional: \(isOptional),
                hasIndex: \(hasIndex),
                indexType: \(indexTypeParam),
                isComputed: \(isComputed),
                isRelation: \(isRelation)
            )
            """

            fieldDescriptors.append(descriptor)
        }

        let fieldsArray = fieldDescriptors.isEmpty ? "[]" : """
        [
                \(fieldDescriptors.joined(separator: ",\n        "))
            ]
        """

        return """
        public static let _schemaDescriptor = SchemaDescriptor(
            tableName: "\(raw: tableName)",
            fields: \(raw: fieldsArray)
        )
        """
    }
}

// MARK: - Field Info

/// Information about a field extracted from the struct
private struct FieldInfo {
    let name: String
    let typeString: String
    let isOptional: Bool
    let hasIndex: Bool
    let indexType: String?
    let isComputed: Bool
    let isRelation: Bool
}

// MARK: - Errors

enum MacroError: String, DiagnosticMessage {
    case onlyApplicableToStruct

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@Surreal can only be applied to struct declarations"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SurrealDBMacros", id: rawValue)
    }
}
