// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SurrealDB",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "SurrealDB",
            targets: ["SurrealDB"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "SurrealDB",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SurrealDBTests",
            dependencies: ["SurrealDB"]
        )
    ]
)
