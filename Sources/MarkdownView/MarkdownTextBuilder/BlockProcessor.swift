//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import CoreText
import MarkdownParser
import UIKit

// MARK: - BlockProcessor

final class BlockProcessor {
    private let theme: MarkdownTheme
    private let viewProvider: ReusableViewProvider
    private let context: MarkdownTextView.PreprocessedContent
    private let thematicBreakDrawing: TextBuilder.DrawingCallback?
    private let codeDrawing: TextBuilder.DrawingCallback?
    private let tableDrawing: TextBuilder.DrawingCallback?
    private let blockquoteMarking: TextBuilder.BlockquoteMarkingCallback?
    private let blockquoteDrawing: TextBuilder.BlockquoteDrawingCallback?

    init(
        theme: MarkdownTheme,
        viewProvider: ReusableViewProvider,
        context: MarkdownTextView.PreprocessedContent,
        thematicBreakDrawing: TextBuilder.DrawingCallback?,
        codeDrawing: TextBuilder.DrawingCallback?,
        tableDrawing: TextBuilder.DrawingCallback?,
        blockquoteMarking: TextBuilder.BlockquoteMarkingCallback?,
        blockquoteDrawing: TextBuilder.BlockquoteDrawingCallback?
    ) {
        self.theme = theme
        self.viewProvider = viewProvider
        self.context = context
        self.thematicBreakDrawing = thematicBreakDrawing
        self.codeDrawing = codeDrawing
        self.tableDrawing = tableDrawing
        self.blockquoteMarking = blockquoteMarking
        self.blockquoteDrawing = blockquoteDrawing
    }

    func processHeading(level _: Int, contents: [MarkdownInlineNode]) -> NSAttributedString {
        let font: UIFont = theme.fonts.title

        return buildWithParagraphSync { paragraph in
            paragraph.paragraphSpacing = 16
            paragraph.paragraphSpacingBefore = 16
        } content: {
            let string = contents.render(theme: theme, context: context, viewProvider: viewProvider)
            string.addAttributes(
                [.font: font],
                range: NSRange(location: 0, length: string.length)
            )
            return string
        }
    }

    func processParagraph(contents: [MarkdownInlineNode]) -> NSAttributedString {
        buildWithParagraphSync { paragraph in
            paragraph.paragraphSpacing = 16
            paragraph.lineSpacing = 4
        } content: {
            let rendered = contents.render(theme: theme, context: context, viewProvider: viewProvider)
            if rendered.length == 0 {
                return NSMutableAttributedString(string: " ", attributes: [.font: theme.fonts.body])
            }
            return rendered
        }
    }

    func processThematicBreak() -> NSAttributedString {
        buildWithParagraphSync {
            let drawingCallback = self.thematicBreakDrawing
            let attachment = MarkdownAttachment.hold(attrString: .init(string: "\n\n"))
            var attributes: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.body,
            ]
            attributes.merge(attachment: attachment)
            let drawingAction = MarkdownLineDrawingAction { context, line, lineOrigin, usedRect in
                drawingCallback?(context, line, lineOrigin, usedRect)
            }
            attributes.merge(lineDrawing: drawingAction)
            return .init(string: MarkdownReplacementText.attachment, attributes: attributes)
        }
    }

    func processCodeBlock(
        language: String?,
        content: String,
        highlightMap: CodeHighlighter.HighlightMap
    ) -> (NSAttributedString, CodeView) {
        let content = content.deletingSuffix(of: .whitespacesAndNewlines)
        let codeView = viewProvider.acquireCodeView()
        codeView.theme = theme
        codeView.language = language ?? ""
        codeView.highlightMap = highlightMap
        codeView.content = content
        let drawer = codeDrawing!
        let intrinsicHeight = CodeView.intrinsicHeight(for: content, theme: theme)
        let text = buildWithParagraphSync { paragraph in
            paragraph.minimumLineHeight = intrinsicHeight
        } content: {
            let attachment = MarkdownAttachment.hold(attrString: .init(string: content + "\n"))
            attachment.size = .init(width: 0, height: intrinsicHeight)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.body,
                .contextView: codeView,
            ]
            attributes.merge(attachment: attachment)
            attributes.merge(lineDrawing: MarkdownLineDrawingAction { drawer($0, $1, $2, $3) })
            attachment.view = codeView
            return .init(string: MarkdownReplacementText.attachment, attributes: attributes)
        }
        return (text, codeView)
    }

    func processBlockquote(_ children: [MarkdownBlockNode]) -> NSAttributedString {
        guard !children.isEmpty else { return NSAttributedString() }

        let result = NSMutableAttributedString()

        let baseParagraphStyle = NSMutableParagraphStyle()
        baseParagraphStyle.firstLineHeadIndent = 16
        baseParagraphStyle.headIndent = 16
        baseParagraphStyle.tailIndent = -4
        baseParagraphStyle.paragraphSpacing = 8
        baseParagraphStyle.lineSpacing = 4

        let drawingContext = BlockquoteDrawingContext(
            fillColor: theme.colors.body.withAlphaComponent(0.1),
            headIndent: baseParagraphStyle.headIndent
        )

        for child in children {
            guard case let .paragraph(content) = child else {
                assertionFailure("Blockquote should only contain paragraphs after flattening")
                continue
            }
            let paragraphContent = content.render(theme: theme, context: context, viewProvider: viewProvider)
            result.append(paragraphContent)
        }

        while result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        guard result.length > 0 else { return result }
//        result.append(.init(string: "\n"))

        result.addAttribute(
            .paragraphStyle,
            value: baseParagraphStyle, range: NSRange(location: 0, length: result.length)
        )
        result.addAttribute(
            .blockquoteContext,
            value: drawingContext,
            range: NSRange(location: 0, length: result.length)
        )

        let marker = blockquoteMarking!
        let drawer = blockquoteDrawing!

        result.insert(buildWithParagraphSync(withNewLine: false) { paragraph in
            paragraph = baseParagraphStyle
        } content: {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.body,
                .paragraphStyle: baseParagraphStyle,
            ]
            attributes[.blockquoteContext] = drawingContext
            attributes.merge(lineDrawing: MarkdownLineDrawingAction { marker($0, $1, $2, $3) })
            return .init(string: MarkdownReplacementText.attachment, attributes: attributes)
        }, at: 0)
        result.append(buildWithParagraphSync(withNewLine: true) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.body,
                .paragraphStyle: baseParagraphStyle,
            ]
            attributes[.blockquoteContext] = drawingContext
            attributes.merge(lineDrawing: MarkdownLineDrawingAction { drawer($0, $1, $2, $3) })
            return .init(string: MarkdownReplacementText.attachment, attributes: attributes)
        })

        return result
    }

    func processTable(rows: [RawTableRow]) -> (NSAttributedString, TableView) {
        let tableView = viewProvider.acquireTableView()
        let contents = rows.map {
            $0.cells.map { rawCell in
                rawCell.content.render(theme: theme, context: context, viewProvider: viewProvider)
            }
        }
        let allContent = contents
            .map { $0.map(\.string).joined(separator: "\t") }
            .joined(separator: "\n")
        let representedText = NSAttributedString(string: allContent + "\n")
        tableView.setContents(contents)
        let drawer = tableDrawing!

        let intrinsicHeight = tableView.intrinsicContentHeight
        let text = buildWithParagraphSync { paragraph in
            paragraph.minimumLineHeight = intrinsicHeight
        } content: {
            let attachment = MarkdownAttachment.hold(attrString: representedText)
            attachment.size = .init(width: 0, height: intrinsicHeight)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.body,
                .contextView: tableView,
            ]
            attributes.merge(attachment: attachment)
            attributes.merge(lineDrawing: MarkdownLineDrawingAction { drawer($0, $1, $2, $3) })
            attachment.view = tableView
            return .init(string: MarkdownReplacementText.attachment, attributes: attributes)
        }
        return (text, tableView)
    }
}

// MARK: - Paragraph Helper

extension BlockProcessor {
    private func buildWithParagraphSync(
        withNewLine: Bool = true,
        modifier: (inout NSMutableParagraphStyle) -> Void = { _ in },
        content: () -> NSMutableAttributedString
    ) -> NSMutableAttributedString {
        var paragraphStyle: NSMutableParagraphStyle = .init()
        paragraphStyle.paragraphSpacing = 16
        paragraphStyle.lineSpacing = 4
        modifier(&paragraphStyle)

        let string = content()
        string.addAttributes(
            [.paragraphStyle: paragraphStyle],
            range: .init(location: 0, length: string.length)
        )
        if withNewLine, !string.string.hasSuffix("\n") {
            string.append(.init(string: "\n"))
        }
        return string
    }

    private func removeLeadingSpacing(from attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = attributedString.mutableCopy() as! NSMutableAttributedString
        mutableString.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: mutableString.length), options: []) { value, range, _ in
            if let style = value as? NSParagraphStyle {
                let mutableStyle = style.mutableCopy() as! NSMutableParagraphStyle
                mutableStyle.paragraphSpacingBefore = 0
                mutableString.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
            }
        }
        return mutableString
    }
}
