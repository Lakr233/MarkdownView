//
//  MarkdownView+RepresentableBase.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import MarkdownParser
import SwiftUI

@MainActor
protocol MarkdownViewRepresentableBase {
    var contentSource: MarkdownView.ContentSource { get }
    var theme: MarkdownTheme { get }
    /// `nil` for a plain view; see `MarkdownView.streaming(_:)`.
    var isStreaming: Bool? { get }
}

extension MarkdownViewRepresentableBase {
    func createMarkdownTextView() -> MarkdownTextView {
        let view = isStreaming == nil ? MarkdownTextView() : MarkdownStreamView()
        view.theme = theme
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateMarkdownTextView(_ view: MarkdownTextView, coordinator: MarkdownViewCoordinator) {
        // Set before the text, so the last update of a stream that just ended
        // appears at once.
        (view as? MarkdownStreamView)?.isStreaming = isStreaming ?? false
        switch contentSource {
        case let .text(text):
            // A view last fed prebuilt content is showing that content, not
            // `lastText`, so any text replaces it — even the empty string.
            // The end of a stream changes what is parsed, not the text.
            let isStreaming = isStreaming ?? false
            let needsUpdate = coordinator.lastContent != nil
                || coordinator.targetText != text
                || coordinator.targetTheme != theme
                || coordinator.targetIsStreaming != isStreaming
            if needsUpdate {
                coordinator.setTextThrottled(text, theme: theme, isStreaming: isStreaming, on: view)
            }

        case let .content(markdownContent):
            let needsUpdate = coordinator.lastContent !== markdownContent
                || coordinator.lastTheme != theme
            if needsUpdate {
                coordinator.cancelScheduledApply()
                coordinator.lastText = ""
                coordinator.lastParsedText = ""
                coordinator.lastParseResult = nil
                coordinator.lastContent = markdownContent
                view.setContentImmediately(markdownContent, theme: theme)
                coordinator.lastTheme = theme
            }
        }
    }
}
