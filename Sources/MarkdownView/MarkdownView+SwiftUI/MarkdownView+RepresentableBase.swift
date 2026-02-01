//
//  MarkdownView+RepresentableBase.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import MarkdownParser
import SwiftUI

protocol MarkdownViewRepresentableBase {
    var contentSource: MarkdownView.ContentSource { get }
    var theme: MarkdownTheme { get }
    var width: CGFloat { get }
    var heightBinding: Binding<CGFloat> { get }
}

extension MarkdownViewRepresentableBase {
    func createMarkdownTextView() -> MarkdownTextView {
        let view = MarkdownTextView()
        view.theme = theme
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateMarkdownTextView(_ view: MarkdownTextView, coordinator: MarkdownViewCoordinator) {
        let needsUpdate: Bool
        let content: MarkdownTextView.PreprocessedContent

        switch contentSource {
        case let .text(text):
            needsUpdate = coordinator.lastText != text
                || coordinator.lastTheme != theme
            if needsUpdate {
                let parser = MarkdownParser()
                let result = parser.parse(text)
                content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
                coordinator.lastText = text
                coordinator.lastPreprocessedContent = nil
            } else {
                content = view.document
            }

        case let .preprocessed(preprocessedContent):
            needsUpdate = coordinator.lastPreprocessedContent !== preprocessedContent
                || coordinator.lastTheme != theme
            content = preprocessedContent
            if needsUpdate {
                coordinator.lastText = ""
                coordinator.lastPreprocessedContent = preprocessedContent
            }
        }

        if needsUpdate {
            view.theme = theme
            view.setMarkdownManually(content)
            view.invalidateIntrinsicContentSize()
            coordinator.lastTheme = theme
        }
        updateMeasuredHeight(for: view)
    }

    func updateMeasuredHeight(for view: MarkdownTextView) {
        guard width.isFinite, width > 0 else { return }
        let size = view.boundingSize(for: width)
        let height = ceil(size.height)
        guard abs(height - heightBinding.wrappedValue) > 0.5 else { return }
        DispatchQueue.main.async {
            self.heightBinding.wrappedValue = height
        }
    }
}
