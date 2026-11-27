// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KadrPhotos",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
        // tvOS deliberately excluded — Apple doesn't ship Photos.framework on tvOS.
    ],
    products: [
        .library(name: "KadrPhotos", targets: ["KadrPhotos"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SteliyanH/kadr.git", from: "1.0.0"),
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
        // Compiles the README's examples, so they cannot drift from the API.
        // Tools/readme-snippets.sh generates Examples/ReadmeSnippets.swift from
        // README.md; CI fails if that copy is stale. Built, never run.
        .target(
            name: "KadrPhotosExamples",
            dependencies: [
                "KadrPhotos",
                .product(name: "Kadr", package: "kadr"),
            ],
            path: "Examples",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "KadrPhotosTests",
            dependencies: ["KadrPhotos"]
        ),
    ]
)
