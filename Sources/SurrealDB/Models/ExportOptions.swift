import Foundation

/// Options for configuring database export operations.
///
/// Use this to control which data is included in an export.
public struct ExportOptions: Sendable, Encodable {
    /// The specific tables to export. If nil, all tables are exported.
    public let tables: [String]?

    /// Whether to include custom functions in the export.
    public let functions: Bool

    /// Creates export options with default values.
    ///
    /// - Parameters:
    ///   - tables: The tables to export. Pass nil to export all tables.
    ///   - functions: Whether to include functions. Defaults to true.
    public init(tables: [String]? = nil, functions: Bool = true) {
        self.tables = tables
        self.functions = functions
    }

    /// Default export options that export all tables and functions.
    public static let `default` = ExportOptions(tables: nil, functions: true)
}
