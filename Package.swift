// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BloomingMarvellous",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "BloomingMarvellous", targets: ["BloomingMarvellous"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BloomingMarvellous",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
        .testTarget(
            name: "BloomingMarvellouslTests",
            dependencies: ["BloomingMarvellous"],
            path: "Tests"
        )
    ]
)
