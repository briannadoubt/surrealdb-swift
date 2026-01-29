import Foundation

/// Efficient ID generation for parameter bindings and requests.
enum IDGenerator {
    /// Generates a compact parameter binding name.
    internal static func generateBindingID() -> String {
        // Use compact hex representation of UUID bytes
        var uuid = UUID().uuid
        return withUnsafeBytes(of: &uuid) { buffer in
            let bytes = Array(buffer.prefix(8))
            return "p_" + bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Generates a compact UUID for request IDs.
    internal static func generateRequestID() -> String {
        // Filter out dashes more efficiently
        UUID().uuidString.filter { $0 != "-" }
    }
}
