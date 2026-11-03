// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CommonCopyMobileCore", platforms: [.macOS(.v13), .iOS(.v16)], products: [.library(name: "CommonCopyMobileCore", targets: ["CommonCopyMobileCore"])], targets: [.target(name: "CommonCopyMobileCore", path: "Core"), .testTarget(name: "CommonCopyMobileCoreTests", dependencies: ["CommonCopyMobileCore"], path: "Tests")])
