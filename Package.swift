// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "poietic-core",
    platforms: [.macOS("15"), .custom("linux", versionString: "1")],
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
