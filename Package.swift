// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "claude-notify",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "claude-notify",
            path: "Sources"
        ),
        .testTarget(
            name: "claude-notifyTests",
            dependencies: ["claude-notify"],
            path: "Tests/claude-notifyTests"
        )
    ]
)
