// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SQLiteReader",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SQLiteReader", targets: ["SQLiteReader"]),
    ],
    targets: [
        // Links the system libsqlite3 automatically via `import SQLite3`.
        .target(name: "SQLiteReader", path: "Sources",
                swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "SQLiteReaderTests", dependencies: ["SQLiteReader"], path: "Tests"),
    ]
)
