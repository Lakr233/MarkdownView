//
//  WatchMarkdownView.swift
//  WatchMarkdownView
//
//  Read-only markdown renderer for watchOS.
//
//  Architecture:
//  - A single LitextLabel on watchOS
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
    private let blocks: [MarkdownBlockNode]
    private let theme: WatchMarkdownTheme
    private let contentWidth: CGFloat

    @Environment(\.displayScale) private var displayScale

    // MARK: - Initializers

    /// Parse and display a Markdown string.
    public init(
        markdown: String,
        theme: WatchMarkdownTheme = .default,
        contentWidth: CGFloat = 200
    ) {
        self.theme = theme
        self.contentWidth = contentWidth
        blocks = MarkdownParser().parse(markdown).document
    }

    /// Display pre-parsed blocks (e.g. when you already hold a ParseResult).
    public init(
        blocks: [MarkdownBlockNode],
        theme: WatchMarkdownTheme = .default,
        contentWidth: CGFloat = 200
    ) {
        self.blocks = blocks
        self.theme = theme
        self.contentWidth = contentWidth
    }

    // MARK: - Body

    public var body: some View {
        LitextLabel(attributedString: attributedString)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedString: NSAttributedString {
        WatchTextBuilder(
            blocks: blocks,
            theme: theme,
            maxWidth: contentWidth,
            scale: displayScale
        )
        .build()
    }
}
