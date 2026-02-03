import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The compiler plugin entry point for SurrealDB macros.
@main
struct SurrealDBMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SurrealMacro.self,
        SurrealEdgeMacro.self
    ]
}

// String extension for whitespace trimming (Foundation is not available in macro context)
extension String {
    func trimmingWhitespace() -> String {
        var start = self.startIndex
        var end = self.endIndex

        // Trim leading whitespace
        while start < end && self[start].isWhitespace {
            start = self.index(after: start)
        }

        // Trim trailing whitespace
        while start < end {
            let prevIndex = self.index(before: end)
            if self[prevIndex].isWhitespace {
                end = prevIndex
            } else {
                break
            }
        }

        return String(self[start..<end])
    }
}
