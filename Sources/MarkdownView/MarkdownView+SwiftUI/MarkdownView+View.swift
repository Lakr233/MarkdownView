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
    /// `nil` until ``streaming(_:)`` is applied; see there.
    var isStreaming: Bool?

    public init(_ text: String, theme: MarkdownTheme = .default) {
        contentSource = .text(text)
        self.theme = theme
    }

    public init(_ content: MarkdownContent, theme: MarkdownTheme = .default) {
        contentSource = .content(content)
        self.theme = theme
    }

    public var body: some View {
        // Single-phase layout: the representable reports its height
        // synchronously through sizeThatFits(_:), so no measured-height
        // state (and no second layout pass) is needed here.
        MarkdownViewRepresentable(
            contentSource: contentSource,
            theme: theme,
            isStreaming: isStreaming,
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Shows the text as a document that is still being written: while
    /// `isStreaming` is `true`, each update fades its new text in, and
    /// rebuilds are paced by what they cost. See ``MarkdownStreamView``.
    ///
    /// A view this is applied to is drawn by a ``MarkdownStreamView``, even
    /// while `isStreaming` is `false`, so keep the modifier on a view whose
    /// stream ends rather than adding and removing it.
    public func streaming(_ isStreaming: Bool = true) -> MarkdownView {
        var view = self
        view.isStreaming = isStreaming
        return view
    }
}
