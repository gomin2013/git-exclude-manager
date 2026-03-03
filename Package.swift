// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GitExcludeManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GitExcludeManager", targets: ["GitExcludeManagerApp"]),
        .executable(name: "GitExcludeManagerHelper", targets: ["GitExcludeManagerHelper"])
    ],
    dependencies: [],
    targets: [
        // MARK: - Shared Module (Protocol, Models, Error Types)
        .target(
            name: "Shared",
            dependencies: [],
            path: "Sources/Shared"
        ),

        // MARK: - Main App
        .executableTarget(
            name: "GitExcludeManagerApp",
            dependencies: ["Shared"],
            path: "Sources/GitExcludeManagerApp",
            resources: [
                .process("Resources")
            ]
        ),

        // MARK: - Helper Daemon
        .executableTarget(
            name: "GitExcludeManagerHelper",
            dependencies: ["Shared"],
            path: "Sources/GitExcludeManagerHelper"
        ),

        // MARK: - Tests
        .testTarget(
            name: "GitExcludeManagerTests",
            dependencies: ["Shared", "GitExcludeManagerApp"],
            path: "Tests/GitExcludeManagerTests"
        )
    ]
)
