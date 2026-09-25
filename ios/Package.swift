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
    dependencies: [
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            from: "0.9.20"
        )
    ],
    targets: [
        .target(
            name: "EdgeFrameworks",
            dependencies: [
                .product(
                    name: "ZIPFoundation",
                    package: "ZIPFoundation"
                )
            ]
        ),
        .testTarget(
            name: "EdgeFrameworksTests",
            dependencies: ["EdgeFrameworks"]
        )
    ]
)
