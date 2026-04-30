// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KadrPhotos",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
        // tvOS deliberately excluded — Apple doesn't ship Photos.framework on tvOS.
    ],
    products: [
        .library(name: "KadrPhotos", targets: ["KadrPhotos"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SteliyanH/kadr.git", from: "0.9.2"),
    ],
    targets: [
        .target(
            name: "KadrPhotos",
            dependencies: [
                .product(name: "Kadr", package: "kadr"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "KadrPhotosTests",
            dependencies: ["KadrPhotos"]
        ),
    ]
)
