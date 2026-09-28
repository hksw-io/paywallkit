// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PaywallKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "PaywallKit",
            targets: ["PaywallKit"]),
    ],
    targets: [
        .target(
            name: "PaywallKit",
            resources: [.process("Resources")]),
        .testTarget(
            name: "PaywallKitTests",
            dependencies: ["PaywallKit"]),
    ])
