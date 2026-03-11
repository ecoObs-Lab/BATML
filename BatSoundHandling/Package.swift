// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BatSoundHandling",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
      ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BatSoundHandling",
            targets: ["BatSoundHandling"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/koher/swift-image.git", .upToNextMajor(from: "0.8.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BatSoundHandling",
            dependencies: [.product(name: "SwiftImage", package: "swift-image")],
            resources: [
            .process("Resources/Redscale.png"),
            .process("Resources/Greyscale.png"),
            .process("Resources/Bright.png")
            ]
        ),
        .testTarget(
            name: "BatSoundHandlingTests",
            dependencies: ["BatSoundHandling"]
        ),
    ]
)

//
