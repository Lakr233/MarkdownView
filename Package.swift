// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownView",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macCatalyst(.v15),
        .macOS(.v12),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "MarkdownView", targets: ["MarkdownView"]),
        .library(name: "MarkdownParser", targets: ["MarkdownParser"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/Litext", from: "0.5.5"),
        .package(url: "https://github.com/mgriebling/SwiftMath", from: "1.7.3"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
        .package(url: "https://github.com/raspu/Highlightr", from: "2.3.0"),
        .package(url: "https://github.com/swiftlang/swift-cmark", from: "0.7.1"),
        .package(url: "https://github.com/nicklockwood/LRUCache", from: "1.0.7"),
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
        .target(name: "MarkdownParser", dependencies: [
            .product(name: "cmark-gfm", package: "swift-cmark"),
            .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
        ]),
    ]
)
