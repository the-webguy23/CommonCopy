// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommonCopyMac",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CommonCopyMac", targets: ["CommonCopyMac"])],
    targets: [
        .executableTarget(name: "CommonCopyMac"),
        .executableTarget(name: "CommonCopyFixture", path: "Tests/Fixtures/CommonCopyFixture"),
        .testTarget(name: "CommonCopyMacTests", dependencies: ["CommonCopyMac"])
    ]
)
