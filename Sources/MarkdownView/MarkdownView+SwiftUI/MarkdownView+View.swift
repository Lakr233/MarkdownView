//
//  MarkdownView+View.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import MarkdownParser
import SwiftUI

public struct MarkdownView: View {
    @available(*, deprecated, renamed: "MarkdownContent")
    public typealias PreprocessedContent = MarkdownContent

    enum ContentSource {
        case text(String)
        case content(MarkdownContent)
    }

    let contentSource: ContentSource
    public var theme: MarkdownTheme

    @State private var measuredHeight: CGFloat = 0

    public init(_ text: String, theme: MarkdownTheme = .default) {
        contentSource = .text(text)
        self.theme = theme
    }

    public init(_ content: MarkdownContent, theme: MarkdownTheme = .default) {
        contentSource = .content(content)
        self.theme = theme
    }

    public var body: some View {
        MarkdownViewRepresentable(
            contentSource: contentSource,
            theme: theme,
            measuredHeight: $measuredHeight
        )
        .frame(
            maxWidth: .infinity,
            minHeight: measuredHeight,
            idealHeight: measuredHeight > 0 ? measuredHeight : nil,
            maxHeight: measuredHeight > 0 ? measuredHeight : nil,
            alignment: .topLeading
        )
    }
}
