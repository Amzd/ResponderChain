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
        .package(name: "Introspect", url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "0.1.2"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.6.0"),
    ],
    targets: [
        .target(name: "ResponderChain", dependencies: ["Introspect"]),
        .testTarget(name: "ResponderChainTests", dependencies: ["ResponderChain", "ViewInspector"]),
    ]
)
