// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PoieticCore",
    platforms: [.macOS("14"), .custom("linux", versionString: "1")],
    products: [
        .library(
            name: "PoieticCore",
            targets: ["PoieticCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "PoieticCore",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
        .testTarget(
            name: "PoieticCoreTests",
            dependencies: ["PoieticCore"]),
    ]
)
