// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ResponderChain",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "ResponderChain", targets: ["ResponderChain"]),
    ],
    dependencies: [
        .package(name: "Introspect", url: "https://github.com/timbersoftware/SwiftUI-Introspect.git", .upToNextMajor(from: "0.1.0"))
    ],
    targets: [
        .target(name: "ResponderChain", dependencies: ["Introspect"]),
//        .testTarget(name: "ResponderChainTests", dependencies: ["ResponderChain"]),
    ]
)
