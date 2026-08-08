//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import CoreText
import Litext
import MarkdownParser
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@MainActor
final class TextBuilder {
    private let nodes: [MarkdownBlockNode]
    private let viewProvider: ReusableViewProvider
    private var theme: MarkdownTheme = .default
    private let text: NSMutableAttributedString = .init()
    private let context: MarkdownContent

    private var bulletDrawing: BulletDrawingCallback?
    private var numberedDrawing: NumberedDrawingCallback?
    private var checkboxDrawing: CheckboxDrawingCallback?
    private var thematicBreakDrawing: DrawingCallback?

    init(
        nodes: [MarkdownBlockNode],
        context: MarkdownContent,
        viewProvider: ReusableViewProvider
    ) {
        self.nodes = nodes
        self.context = context
        self.viewProvider = viewProvider
    }

    func withTheme(_ theme: MarkdownTheme) -> TextBuilder {
        self.theme = theme
        return self
    }

    func withBulletDrawing(_ drawing: @escaping BulletDrawingCallback) -> TextBuilder {
        bulletDrawing = drawing
        return self
    }

    func withNumberedDrawing(_ drawing: @escaping NumberedDrawingCallback) -> TextBuilder {
        numberedDrawing = drawing
        return self
    }

    func withCheckboxDrawing(_ drawing: @escaping CheckboxDrawingCallback) -> TextBuilder {
        checkboxDrawing = drawing
        return self
    }

    func withThematicBreakDrawing(_ drawing: @escaping DrawingCallback) -> TextBuilder {
        thematicBreakDrawing = drawing
        return self
    }

    struct BuildResult {
        let document: NSAttributedString
        let subviews: [PlatformView]
        /// Highlight cache keys of every code block in this document, so a view
        /// can tell whether a finished highlight is one of its own.
        let highlightKeys: Set<Int>
    }

    private var pendingHighlightRequests: [CodeHighlightRequest] = []
    private var highlightKeys: Set<Int> = []

    private var previouslyBuilt = false
    func build() -> BuildResult {
        assert(!previouslyBuilt, "TextBuilder can only be built once.")
        previouslyBuilt = true
        var subviewCollector = [PlatformView]()
        for node in nodes {
            text.append(processBlock(node, context: context, subviews: &subviewCollector))
        }
        text.fixAttributes(in: .init(location: 0, length: text.length))
        if !pendingHighlightRequests.isEmpty {
            CodeHighlighter.current.scheduleHighlight(requests: pendingHighlightRequests)
        }
        return .init(document: text, subviews: subviewCollector, highlightKeys: highlightKeys)
    }
}

// MARK: - Block Processing

extension TextBuilder {
    private func processBlock(
        _ node: MarkdownBlockNode,
        context: MarkdownContent,
        subviews: inout [PlatformView]
    ) -> NSAttributedString {
        let blockProcessor = BlockProcessor(
            theme: theme,
            viewProvider: viewProvider,
            context: context,
            thematicBreakDrawing: thematicBreakDrawing,
        )

        let listProcessor = ListProcessor(
            theme: theme,
            viewProvider: viewProvider,
            context: context,
            bulletDrawing: bulletDrawing,
            numberedDrawing: numberedDrawing,
            checkboxDrawing: checkboxDrawing
        )

        switch node {
        case let .heading(level, contents):
            return blockProcessor.processHeading(level: level, contents: contents)
        case let .paragraph(contents):
            return blockProcessor.processParagraph(contents: contents)
        case let .bulletedList(_, items):
            return listProcessor.processBulletedList(items: items)
        case let .numberedList(_, index, items):
            return listProcessor.processNumberedList(startAt: index, items: items)
        case let .taskList(_, items):
            return listProcessor.processTaskList(items: items)
        case .thematicBreak:
            return blockProcessor.processThematicBreak()
        case let .codeBlock(language, content):
            let highlightKey = CodeHighlighter.current.key(for: content, language: language)
            highlightKeys.insert(highlightKey)
            var highlightMap = context.highlightMaps[highlightKey]
            if highlightMap == nil {
                highlightMap = CodeHighlighter.current.cachedHighlightMap(for: highlightKey)
                if highlightMap == nil {
                    pendingHighlightRequests.append(.init(key: highlightKey, content: content, language: language))
                }
            }
            let result = blockProcessor.processCodeBlock(
                language: language,
                content: content,
                highlightMap: highlightMap
            )
            subviews.append(result.1)
            return result.0
        case let .blockquote(children):
            return blockProcessor.processBlockquote(children)
        case let .table(columnAlignments, rows):
            let result = blockProcessor.processTable(
                columnAlignments: columnAlignments,
                rows: rows
            )
            subviews.append(result.1)
            return result.0
        }
    }
}
