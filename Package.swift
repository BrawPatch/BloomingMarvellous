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
        .library(name: "BloomingMarvellousUI", targets: ["BloomingMarvellousUI"]),
        .executable(name: "BloomingMarvellousDemoApp", targets: ["BloomingMarvellousDemoApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BloomingMarvellous",
            path: "Sources",
            exclude: ["UI"]
        ),
        .target(
            name: "BloomingMarvellousUI",
            dependencies: ["BloomingMarvellous"],
            path: "Sources/UI"
        ),
        .executableTarget(
            name: "BloomingMarvellousDemoApp",
            dependencies: ["BloomingMarvellousUI"],
            path: "App"
        ),
        .testTarget(
            name: "BloomingMarvellouslTests",
            dependencies: ["BloomingMarvellous"],
            path: "Tests"
        )
    ]
)
