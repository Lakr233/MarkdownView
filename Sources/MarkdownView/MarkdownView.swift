//
//  MarkdownView.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import MarkdownParser
import SwiftUI

#if canImport(UIKit)
    import UIKit

    public struct MarkdownView: UIViewRepresentable {
        public let text: String
        public var theme: MarkdownTheme

        public init(_ text: String, theme: MarkdownTheme = .default) {
            self.text = text
            self.theme = theme
        }

        public func makeUIView(context _: Context) -> MarkdownTextView {
            let view = MarkdownTextView()
            view.theme = theme
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return view
        }

        public func updateUIView(_ uiView: MarkdownTextView, context _: Context) {
            uiView.theme = theme
            let parser = MarkdownParser()
            let result = parser.parse(text)
            let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
            uiView.setMarkdownManually(content)
            uiView.invalidateIntrinsicContentSize()
        }

        public func sizeThatFits(
            _ proposal: ProposedViewSize,
            uiView: MarkdownTextView,
            context _: Context
        ) -> CGSize {
            let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
            return uiView.boundingSize(for: width)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    public struct MarkdownView: NSViewRepresentable {
        public let text: String
        public var theme: MarkdownTheme

        public init(_ text: String, theme: MarkdownTheme = .default) {
            self.text = text
            self.theme = theme
        }

        public func makeNSView(context _: Context) -> MarkdownTextView {
            let view = MarkdownTextView()
            view.theme = theme
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return view
        }

        public func updateNSView(_ nsView: MarkdownTextView, context _: Context) {
            nsView.theme = theme
            let parser = MarkdownParser()
            let result = parser.parse(text)
            let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
            nsView.setMarkdownManually(content)
            nsView.invalidateIntrinsicContentSize()
        }

        public func sizeThatFits(
            _ proposal: ProposedViewSize,
            nsView: MarkdownTextView,
            context _: Context
        ) -> CGSize {
            let width = proposal.width ?? NSView.noIntrinsicMetric
            return nsView.boundingSize(for: width)
        }
    }
#endif
