//
//  MarkdownView.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import MarkdownParser
import SwiftUI

public struct MarkdownView: View {
    public let text: String
    public var theme: MarkdownTheme

    @State private var measuredHeight: CGFloat = 0

    public init(_ text: String, theme: MarkdownTheme = .default) {
        self.text = text
        self.theme = theme
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MarkdownViewRepresentable(
                    text: text,
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

#if canImport(UIKit)
    import UIKit

    private struct MarkdownViewRepresentable: UIViewRepresentable {
        let text: String
        let theme: MarkdownTheme
        let width: CGFloat
        @Binding var measuredHeight: CGFloat

        func makeUIView(context _: Context) -> MarkdownTextView {
            let view = MarkdownTextView()
            view.theme = theme
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return view
        }

        func updateUIView(_ uiView: MarkdownTextView, context: Context) {
            if context.coordinator.lastText != text || context.coordinator.lastTheme != theme {
                uiView.theme = theme
                let parser = MarkdownParser()
                let result = parser.parse(text)
                let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
                uiView.setMarkdownManually(content)
                uiView.invalidateIntrinsicContentSize()
                context.coordinator.lastText = text
                context.coordinator.lastTheme = theme
            }
            updateMeasuredHeight(for: uiView)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        private func updateMeasuredHeight(for view: MarkdownTextView) {
            guard width.isFinite, width > 0 else { return }
            let size = view.boundingSize(for: width)
            let height = ceil(size.height)
            guard abs(height - measuredHeight) > 0.5 else { return }
            DispatchQueue.main.async {
                measuredHeight = height
            }
        }

        final class Coordinator {
            var lastText: String = ""
            var lastTheme: MarkdownTheme = .default
        }
    }

#elseif canImport(AppKit)
    import AppKit

    private struct MarkdownViewRepresentable: NSViewRepresentable {
        let text: String
        let theme: MarkdownTheme
        let width: CGFloat
        @Binding var measuredHeight: CGFloat

        func makeNSView(context _: Context) -> MarkdownTextView {
            let view = MarkdownTextView()
            view.theme = theme
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return view
        }

        func updateNSView(_ nsView: MarkdownTextView, context: Context) {
            if context.coordinator.lastText != text || context.coordinator.lastTheme != theme {
                nsView.theme = theme
                let parser = MarkdownParser()
                let result = parser.parse(text)
                let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
                nsView.setMarkdownManually(content)
                nsView.invalidateIntrinsicContentSize()
                context.coordinator.lastText = text
                context.coordinator.lastTheme = theme
            }
            updateMeasuredHeight(for: nsView)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        private func updateMeasuredHeight(for view: MarkdownTextView) {
            guard width.isFinite, width > 0 else { return }
            let size = view.boundingSize(for: width)
            let height = ceil(size.height)
            guard abs(height - measuredHeight) > 0.5 else { return }
            DispatchQueue.main.async {
                measuredHeight = height
            }
        }

        final class Coordinator {
            var lastText: String = ""
            var lastTheme: MarkdownTheme = .default
        }
    }
#endif
