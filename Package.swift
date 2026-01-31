// swift-tools-version: 6.2
import PackageDescription

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
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SurrealDB",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit")
            ]
        ),
        .testTarget(
            name: "SurrealDBTests",
            dependencies: ["SurrealDB"]
        )
    ]
)
