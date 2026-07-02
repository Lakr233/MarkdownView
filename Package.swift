// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownView",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16),
        .macOS(.v13),
        .visionOS(.v1),
        .watchOS(.v8),
    ],
    products: [
        .library(name: "MarkdownView", targets: ["MarkdownView"]),
        .library(name: "MarkdownParser", targets: ["MarkdownParser"]),
        .library(name: "WatchMarkdownView", targets: ["WatchMarkdownView"]),
        .executable(name: "MarkdownViewBenchmark", targets: ["MarkdownViewBenchmark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/Litext", exact: "2.1.3"),
        .package(url: "https://github.com/mgriebling/SwiftMath", exact: "1.7.3"),
        .package(url: "https://github.com/apple/swift-collections", exact: "1.6.0"),
        .package(url: "https://github.com/raspu/Highlightr", exact: "2.3.0"),
        .package(url: "https://github.com/swiftlang/swift-cmark", exact: "0.8.0"),
        .package(url: "https://github.com/nicklockwood/LRUCache", exact: "1.2.1"),
    ],
    targets: [
        .target(
            name: "MarkdownView",
            dependencies: [
                "Litext",
                "Highlightr",
                "MarkdownParser",
                "SwiftMath",
                "LRUCache",
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "WatchMarkdownView",
            dependencies: [
                "Litext",
                "MarkdownParser",
                "LRUCache",
            ]
        ),
        .executableTarget(
            name: "MarkdownViewBenchmark",
            dependencies: [
                "MarkdownView",
                "MarkdownParser",
            ]
        ),
        .target(name: "MarkdownParser", dependencies: [
            .product(name: "cmark-gfm", package: "swift-cmark"),
            .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
        ]),
        .testTarget(
            name: "MarkdownParserTests",
            dependencies: [
                "MarkdownParser",
            ]
        ),
        .testTarget(
            name: "MarkdownViewTests",
            dependencies: [
                "MarkdownView",
                "MarkdownParser",
            ],
            resources: [.process("Fixtures")]
        ),
    ]
)
