//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import CoreText
import Litext
import MarkdownParser
import UIKit

// MARK: - BlockProcessor

final class BlockProcessor {
    private let theme: MarkdownTheme
    private let viewProvider: ReusableViewProvider
    private let context: MarkdownTextView.PreprocessContent
    private let thematicBreakDrawing: TextBuilder.DrawingCallback?
    private let codeDrawing: TextBuilder.DrawingCallback?
    private let tableDrawing: TextBuilder.DrawingCallback?
    private let blockquoteDrawing: TextBuilder.BlockquoteDrawingCallback?

    init(
        theme: MarkdownTheme,
        viewProvider: ReusableViewProvider,
        context: MarkdownTextView.PreprocessContent,
        thematicBreakDrawing: TextBuilder.DrawingCallback?,
        codeDrawing: TextBuilder.DrawingCallback?,
        tableDrawing: TextBuilder.DrawingCallback?,
        blockquoteDrawing: TextBuilder.BlockquoteDrawingCallback?
    ) {
        self.theme = theme
        self.viewProvider = viewProvider
        self.context = context
        self.thematicBreakDrawing = thematicBreakDrawing
        self.codeDrawing = codeDrawing
        self.tableDrawing = tableDrawing
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
            return .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: .init(string: "\n\n")),
                .ltxLineDrawingCallback: LTXLineDrawingAction(action: { context, line, lineOrigin in
                    drawingCallback?(context, line, lineOrigin)
                }),
            ])
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
        let text = buildWithParagraphSync { paragraph in
            let height = CodeView.intrinsicHeight(for: content, theme: theme)
            paragraph.minimumLineHeight = height
        } content: {
            .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: .init(string: content + "\n")),
                .ltxLineDrawingCallback: LTXLineDrawingAction { drawer($0, $1, $2) },
                .contextView: codeView,
            ])
        }
        return (text, codeView)
    }

    func processBlockquote(_ children: [MarkdownBlockNode], depth: Int, processor: (MarkdownBlockNode) -> NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, child) in children.enumerated() {
            let childContent = processor(child)

            if index == 0, case .heading = child {
                result.append(removeLeadingSpacing(from: childContent))
            } else {
                result.append(childContent)
            }
        }

        let blockquoteTheme = theme.blockquote
        let totalIndent = CGFloat(depth + 1) * blockquoteTheme.leftIndent

        result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: result.length), options: []) { value, range, _ in
            let paragraphStyle: NSMutableParagraphStyle = if let existingStyle = value as? NSParagraphStyle {
                existingStyle.mutableCopy() as! NSMutableParagraphStyle
            } else {
                NSMutableParagraphStyle()
            }

            paragraphStyle.firstLineHeadIndent += totalIndent
            paragraphStyle.headIndent += totalIndent
            paragraphStyle.tailIndent = -blockquoteTheme.rightIndent

            if paragraphStyle.paragraphSpacing > 8 {
                paragraphStyle.paragraphSpacing = 8
            }

            result.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }

        applyTextColorAlpha(to: result, alpha: blockquoteTheme.textColorAlpha)

        result.addAttribute(.blockquoteDepth, value: depth, range: NSRange(location: 0, length: result.length))

        if result.length > 0 {
            result.addAttribute(.isBlockquoteStart, value: true, range: NSRange(location: 0, length: 1))
            result.addAttribute(.isBlockquoteEnd, value: true, range: NSRange(location: result.length - 1, length: 1))
        }

        if let blockquoteDrawing {
            result.enumerateAttributes(in: NSRange(location: 0, length: result.length), options: []) { attributes, range, _ in
                if let existingCallback = attributes[.ltxLineDrawingCallback] as? LTXLineDrawingAction {
                    let combinedCallback = LTXLineDrawingAction { context, line, lineOrigin in
                        blockquoteDrawing(context, line, lineOrigin, depth)
                        existingCallback.action(context, line, lineOrigin)
                    }
                    result.addAttribute(.ltxLineDrawingCallback, value: combinedCallback, range: range)
                } else {
                    result.addAttribute(
                        .ltxLineDrawingCallback,
                        value: LTXLineDrawingAction { context, line, lineOrigin in
                            blockquoteDrawing(context, line, lineOrigin, depth)
                        },
                        range: range
                    )
                }
            }
        }

        if result.length > 0, !result.string.hasSuffix("\n") {
            result.append(NSAttributedString(string: "\n"))
        }

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

        let text = buildWithParagraphSync { paragraph in
            paragraph.minimumLineHeight = tableView.intrinsicContentHeight
        } content: {
            .init(string: LTXReplacementText, attributes: [
                .font: theme.fonts.body,
                .ltxAttachment: LTXAttachment.hold(attrString: representedText),
                .ltxLineDrawingCallback: LTXLineDrawingAction { drawer($0, $1, $2) },
                .contextView: tableView,
            ])
        }
        return (text, tableView)
    }
}

// MARK: - Paragraph Helper

extension BlockProcessor {
    private func buildWithParagraphSync(
        modifier: (NSMutableParagraphStyle) -> Void = { _ in },
        content: () -> NSMutableAttributedString
    ) -> NSMutableAttributedString {
        let paragraphStyle: NSMutableParagraphStyle = .init()
        paragraphStyle.paragraphSpacing = 16
        paragraphStyle.lineSpacing = 4
        modifier(paragraphStyle)

        let string = content()
        string.addAttributes(
            [.paragraphStyle: paragraphStyle],
            range: .init(location: 0, length: string.length)
        )
        string.append(.init(string: "\n"))
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

    private func applyTextColorAlpha(to attributedString: NSMutableAttributedString, alpha: CGFloat) {
        let range = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttributes(in: range, options: []) { attributes, range, _ in
            if attributes[.foregroundColor] == nil {
                attributedString.addAttribute(.foregroundColor, value: theme.colors.body, range: range)
            }
        }

        attributedString.enumerateAttribute(.foregroundColor, in: range, options: []) { value, range, _ in
            if let color = value as? UIColor, color.cgColor.alpha >= 1.0 {
                attributedString.addAttribute(.foregroundColor, value: color.withAlphaComponent(alpha), range: range)
            }
        }
    }
}
