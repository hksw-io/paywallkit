// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PaywallKit",
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
        .target(name: "PaywallKit"),
        .testTarget(
            name: "PaywallKitTests",
            dependencies: ["PaywallKit"]),
    ])
