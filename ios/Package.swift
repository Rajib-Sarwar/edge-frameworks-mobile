// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EdgeFrameworks",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "EdgeFrameworks",
            targets: ["EdgeFrameworks"]
        )
    ],
    targets: [
        .target(
            name: "EdgeFrameworks"
        ),
        .testTarget(
            name: "EdgeFrameworksTests",
            dependencies: ["EdgeFrameworks"]
        )
    ]
)
