// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BloomingMarvellous",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "BloomingMarvellous", targets: ["BloomingMarvellous"]),
        .library(name: "BloomingMarvellousUI", targets: ["BloomingMarvellousUI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BloomingMarvellous",
            path: "Sources",
            exclude: ["UI"],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
        .target(
            name: "BloomingMarvellousUI",
            dependencies: ["BloomingMarvellous"],
            path: "Sources/UI"
        ),
        .testTarget(
            name: "BloomingMarvellouslTests",
            dependencies: ["BloomingMarvellous"],
            path: "Tests"
        )
    ]
)
