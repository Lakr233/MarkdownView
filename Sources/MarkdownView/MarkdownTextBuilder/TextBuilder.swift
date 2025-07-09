//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import CoreText
import Litext
import MarkdownParser
import UIKit

final class TextBuilder {
    private let nodes: [MarkdownBlockNode]
    private let viewProvider: ReusableViewProvider
    private var theme: MarkdownTheme = .default
    private let text: NSMutableAttributedString = .init()
    private let context: MarkdownTextView.PreprocessContent

    private var bulletDrawing: BulletDrawingCallback?
    private var numberedDrawing: NumberedDrawingCallback?
    private var checkboxDrawing: CheckboxDrawingCallback?
    private var thematicBreakDrawing: DrawingCallback?
    private var codeDrawing: DrawingCallback?
    private var tableDrawing: DrawingCallback?

    var listIndent: CGFloat = 20

    init(
        nodes: [MarkdownBlockNode],
        context: MarkdownTextView.PreprocessContent,
        viewProvider: ReusableViewProvider,
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

    func withCodeDrawing(_ drawing: @escaping DrawingCallback) -> TextBuilder {
        codeDrawing = drawing
        return self
    }

    func withTableDrawing(_ drawing: @escaping DrawingCallback) -> TextBuilder {
        tableDrawing = drawing
        return self
    }

    struct BuildResult {
        let document: NSAttributedString
        let subviews: [UIView]
     }
    
    private var previouslyBuilt = false
    func build() -> BuildResult {
        assert(!previouslyBuilt, "TextBuilder can only be built once.")
        previouslyBuilt = true
        for node in nodes { text.append(processBlock(node, context: context)) }
        text.fixAttributes(in: .init(location: 0, length: text.length))
        var subviewCollector = [UIView]()
        text.enumerateAttribute(
            .contextView,
            in: .init(location: 0, length: text.length),
            options: [.longestEffectiveRangeNotRequired]
        ) { view, _, _ in
            if let view = view as? UIView { subviewCollector.append(view) }
        }
        return .init(document: text, subviews: [])
    }
}

// MARK: - Block Processing

extension TextBuilder {
    private func processBlock(
        _ node: MarkdownBlockNode,
        context: MarkdownTextView.PreprocessContent
    ) -> NSAttributedString {
        let blockProcessor = BlockProcessor(
            theme: theme,
            viewProvider: viewProvider,
            context: context,
            thematicBreakDrawing: thematicBreakDrawing,
            codeDrawing: codeDrawing,
            tableDrawing: tableDrawing
        )

        let listProcessor = ListProcessor(
            theme: theme,
            listIndent: listIndent,
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
            let highlightMap = context.highlightMaps[highlightKey]
            return blockProcessor.processCodeBlock(
                language: language,
                content: content,
                highlightMap: highlightMap ?? .init()
            )
        case let .blockquote(children):
            return blockProcessor.processBlockquote(children) {
                self.processBlock($0, context: context)
            }
        case let .table(_, rows):
            return blockProcessor.processTable(rows: rows)
        }
    }
}
