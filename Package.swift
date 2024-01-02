// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PoieticCore",
    platforms: [.macOS("13.3"), .custom("linux", versionString: "1")],
    products: [
        .library(
            name: "PoieticCore",
            targets: ["PoieticCore"]),
    ],
    dependencies: [
//        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
        .package(url: "https://github.com/apple/swift-system", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
//        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PoieticCore",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
            ]),
        
        .testTarget(
            name: "PoieticCoreTests",
            dependencies: ["PoieticCore"]),
    ]
)
