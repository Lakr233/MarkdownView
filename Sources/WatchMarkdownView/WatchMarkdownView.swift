//
//  WatchMarkdownView.swift
//  WatchMarkdownView
//
//  Read-only markdown renderer for watchOS.
//
//  Architecture:
//  - A single TextLabel on watchOS
//  - Block elements lowered into one attributed string
//  - Lists, blockquotes, rules, code blocks, and tables rendered via draw actions
//

import Foundation
import Litext
import MarkdownParser
import SwiftUI

/// A read-only SwiftUI view that renders Markdown on watchOS.
///
/// Wrap in a `ScrollView` when the content may exceed screen height.
///
/// ```swift
/// ScrollView {
///     WatchMarkdownView(markdown: text)
///         .padding()
/// }
/// ```
public struct WatchMarkdownView: View {
    private enum Content {
        case markdown(String)
        case blocks([MarkdownBlockNode])
    }

    private let content: Content
    private let theme: WatchMarkdownTheme
    private let contentWidth: CGFloat

    @Environment(\.displayScale) private var displayScale

    @MainActor
    private static var parseCache: [(key: String, blocks: [MarkdownBlockNode])] = []
    private static let parseCacheLimit = 4

    // MARK: - Initializers

    /// Parse and display a Markdown string.
    public init(
        markdown: String,
        theme: WatchMarkdownTheme = .default,
        contentWidth: CGFloat = 200
    ) {
        self.theme = theme
        self.contentWidth = contentWidth
        content = .markdown(markdown)
    }

    /// Display pre-parsed blocks (e.g. when you already hold a ParseResult).
    public init(
        blocks: [MarkdownBlockNode],
        theme: WatchMarkdownTheme = .default,
        contentWidth: CGFloat = 200
    ) {
        content = .blocks(blocks)
        self.theme = theme
        self.contentWidth = contentWidth
    }

    // MARK: - Body

    public var body: some View {
        TextLabel(attributedString: attributedString)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private var attributedString: NSAttributedString {
        WatchTextBuilder(
            blocks: resolvedBlocks,
            theme: theme,
            maxWidth: contentWidth,
            scale: displayScale
        )
        .build()
    }

    @MainActor
    private var resolvedBlocks: [MarkdownBlockNode] {
        switch content {
        case let .blocks(blocks):
            return blocks
        case let .markdown(markdown):
            return Self.parsedBlocks(for: markdown)
        }
    }

    @MainActor
    private static func parsedBlocks(for markdown: String) -> [MarkdownBlockNode] {
        if let index = parseCache.firstIndex(where: { $0.key == markdown }) {
            let entry = parseCache.remove(at: index)
            parseCache.insert(entry, at: 0)
            return entry.blocks
        }
        let blocks = MarkdownParser().parse(markdown).document
        parseCache.insert((key: markdown, blocks: blocks), at: 0)
        if parseCache.count > parseCacheLimit {
            parseCache.removeLast()
        }
        return blocks
    }
}
