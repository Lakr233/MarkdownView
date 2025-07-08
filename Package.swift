// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownView",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13),
    ],
    products: [
        .library(
            name: "MarkdownView",
            targets: ["MarkdownView"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Lakr233/markdown_core", from: "0.1.2"),
        .package(url: "https://github.com/Lakr233/Litext", from: "1.0.2"),
        .package(url: "https://github.com/Lakr233/Splash", from: "0.17.0"),
    ],
    targets: [
        .target(name: "MarkdownView", dependencies: [
            "markdown_core",
            "Litext",
            "Splash",
        ]),
    ]
)
