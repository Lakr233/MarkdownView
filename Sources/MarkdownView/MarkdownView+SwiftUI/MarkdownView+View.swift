//
//  MarkdownView+View.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import MarkdownParser
import SwiftUI

public struct MarkdownView: View {
    public typealias PreprocessedContent = MarkdownTextView.PreprocessedContent

    enum ContentSource {
        case text(String)
        case preprocessed(PreprocessedContent)
    }

    let contentSource: ContentSource
    public var theme: MarkdownTheme

    @State private var measuredHeight: CGFloat = 0

    public init(_ text: String, theme: MarkdownTheme = .default) {
        contentSource = .text(text)
        self.theme = theme
    }

    public init(_ preprocessedContent: PreprocessedContent, theme: MarkdownTheme = .default) {
        contentSource = .preprocessed(preprocessedContent)
        self.theme = theme
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MarkdownViewRepresentable(
                    contentSource: contentSource,
                    theme: theme,
                    width: proxy.size.width,
                    measuredHeight: $measuredHeight
                )
                .frame(
                    width: proxy.size.width,
                    height: measuredHeight,
                    alignment: .topLeading
                )
            }
        }
        .frame(height: measuredHeight)
    }
}
