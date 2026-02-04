// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SurrealDB",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SurrealDB",
            targets: ["SurrealDB"]
        ),
        .library(
            name: "SurrealDBGRDB",
            targets: ["SurrealDBGRDB"]
        ),
        .library(
            name: "SurrealDBLocalStorage",
            targets: ["SurrealDBLocalStorage"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.19.0")
    ],
    targets: [
        // Macro implementation
        .macro(
            name: "SurrealDBMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Main library
        .target(
            name: "SurrealDB",
            dependencies: ["SurrealDBMacros"]
        ),

        // GRDB-backed persistent cache (Apple/Linux only, not WASM)
        .target(
            name: "SurrealDBGRDB",
            dependencies: [
                "SurrealDB",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),

        // localStorage-backed persistent cache (WASM only)
        .target(
            name: "SurrealDBLocalStorage",
            dependencies: [
                "SurrealDB",
                .product(name: "JavaScriptKit", package: "JavaScriptKit")
            ]
        ),

        // Tests
        .testTarget(
            name: "SurrealDBTests",
            dependencies: ["SurrealDB"]
        ),
        .testTarget(
            name: "SurrealDBLocalStorageTests",
            dependencies: [
                "SurrealDB",
                "SurrealDBLocalStorage"
            ]
        )
    ]
)
