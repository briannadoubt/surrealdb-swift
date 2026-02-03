import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The @SurrealEdge macro for SurrealDB edge models.
///
/// This macro:
/// - Extracts From and To type parameters
/// - Generates `static let edgeName: String`
/// - Generates `static let _schemaDescriptor: SchemaDescriptor` with edge metadata
/// - Adds conformance to: EdgeModel, Codable, Sendable, HasSchemaDescriptor
public struct SurrealEdgeMacro: MemberMacro, ExtensionMacro {
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
                    message: EdgeMacroError.onlyApplicableToStruct
                )
            ])
        }

        let typeName = structDecl.name.text
        let edgeName = extractEdgeName(from: node) ?? typeName.lowercased()

        // Extract From and To types
        let (fromType, toType) = try extractEdgeTypes(from: node, context: context)

        var members: [DeclSyntax] = []

        // Generate type aliases
        members.append(
            """
            public typealias From = \(raw: fromType)
            """
        )
        members.append(
            """
            public typealias To = \(raw: toType)
            """
        )

        // Generate edgeName static property
        members.append(
            """
            public static let edgeName: String = "\(raw: edgeName)"
            """
        )

        // Generate _schemaDescriptor
        let fields = try extractFields(from: structDecl, context: context)
        let schemaDescriptor = generateSchemaDescriptor(
            edgeName: edgeName,
            fromType: fromType,
            toType: toType,
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
        // Add conformances (Sendable is auto-synthesized, typealiases are added as members)
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): EdgeModel, Codable, HasSchemaDescriptor {}
            """
        )

        return [extensionDecl]
    }

    // MARK: - Helper Methods

    /// Extract edge name from macro attribute
    private static func extractEdgeName(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments,
              case .argumentList(let list) = arguments else {
            return nil
        }

        // Look for edgeName argument
        for argument in list {
            if let label = argument.label?.text, label == "edgeName",
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first,
               case .stringSegment(let text) = segment {
                return text.content.text
            }
        }

        return nil
    }

    /// Extract From and To types from macro attribute
    private static func extractEdgeTypes(
        from node: AttributeSyntax,
        context: some MacroExpansionContext
    ) throws -> (from: String, to: String) {
        guard let arguments = node.arguments,
              case .argumentList(let list) = arguments else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: node,
                    message: EdgeMacroError.missingFromToTypes
                )
            ])
        }

        var fromType: String?
        var toType: String?

        // Look for from: and to: arguments
        for argument in list {
            if let label = argument.label?.text {
                if label == "from" {
                    fromType = stripSelfSuffix(argument.expression.trimmedDescription)
                } else if label == "to" {
                    toType = stripSelfSuffix(argument.expression.trimmedDescription)
                }
            }
        }

        guard let from = fromType, let to = toType else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: node,
                    message: EdgeMacroError.missingFromToTypes
                )
            ])
        }

        return (from, to)
    }

    /// Strip .self suffix from a type expression
    private static func stripSelfSuffix(_ typeString: String) -> String {
        if typeString.hasSuffix(".self") {
            return String(typeString.dropLast(5)) // Remove ".self"
        }
        return typeString
    }

    /// Extract fields from struct declaration
    private static func extractFields(
        from structDecl: StructDeclSyntax,
        context: some MacroExpansionContext
    ) throws -> [EdgeFieldInfo] {
        var fields: [EdgeFieldInfo] = []

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

                // Skip computed properties
                if isComputed {
                    continue
                }

                // Extract index type if present
                var indexType: String?
                if hasIndexWrapper {
                    indexType = extractIndexType(from: attributes)
                }

                let field = EdgeFieldInfo(
                    name: fieldName,
                    typeString: typeString,
                    isOptional: TypeMapper.isOptional(typeString),
                    hasIndex: hasIndexWrapper,
                    indexType: indexType
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

    /// Generate schema descriptor declaration for edge
    private static func generateSchemaDescriptor(
        edgeName: String,
        fromType: String,
        toType: String,
        fields: [EdgeFieldInfo]
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

            let descriptor = """
            FieldDescriptor(
                name: "\(field.name)",
                type: \(fieldTypeString),
                isOptional: \(isOptional),
                hasIndex: \(hasIndex),
                indexType: \(indexTypeParam)
            )
            """

            fieldDescriptors.append(descriptor)
        }

        let fieldsArray = fieldDescriptors.isEmpty ? "[]" : """
        [
                \(fieldDescriptors.joined(separator: ",\n        "))
            ]
        """

        // Extract table names from types (lowercase the type name)
        let fromTable = fromType.split(separator: ".").last.map(String.init)?.lowercased() ?? fromType.lowercased()
        let toTable = toType.split(separator: ".").last.map(String.init)?.lowercased() ?? toType.lowercased()

        return """
        public static let _schemaDescriptor = SchemaDescriptor(
            tableName: "\(raw: edgeName)",
            fields: \(raw: fieldsArray),
            isEdge: true,
            edgeFrom: "\(raw: fromTable)",
            edgeTo: "\(raw: toTable)"
        )
        """
    }
}

// MARK: - Edge Field Info

/// Information about a field in an edge model
private struct EdgeFieldInfo {
    let name: String
    let typeString: String
    let isOptional: Bool
    let hasIndex: Bool
    let indexType: String?
}

// MARK: - Errors

enum EdgeMacroError: String, DiagnosticMessage {
    case onlyApplicableToStruct
    case missingFromToTypes

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@SurrealEdge can only be applied to struct declarations"
        case .missingFromToTypes:
            return "@SurrealEdge requires 'from:' and 'to:' parameters specifying the source and target model types"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SurrealDBMacros", id: rawValue)
    }
}
