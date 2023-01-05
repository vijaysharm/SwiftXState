// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "SwiftXState",
    products: [
        .library(
            name: "SwiftXState",
            targets: ["SwiftXState"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftXState",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftXStateTests",
            dependencies: ["SwiftXState"]
        ),
    ]
)
