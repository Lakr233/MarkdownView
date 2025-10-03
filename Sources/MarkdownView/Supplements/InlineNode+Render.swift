//
//  InlineNode+Render.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import MarkdownParser
import SwiftMath
import UIKit

extension [MarkdownInlineNode] {
    func render(theme: MarkdownTheme, context: MarkdownTextView.PreprocessedContent, viewProvider: ReusableViewProvider) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for node in self {
            result.append(node.render(theme: theme, context: context, viewProvider: viewProvider))
        }
        return result
    }
}

extension MarkdownInlineNode {
    func render(theme: MarkdownTheme, context: MarkdownTextView.PreprocessedContent, viewProvider: ReusableViewProvider) -> NSAttributedString {
        assert(Thread.isMainThread)
        switch self {
        case let .text(string):
            return NSMutableAttributedString(
                string: string,
                attributes: [
                    .font: theme.fonts.body,
                    .foregroundColor: theme.colors.body,
                ]
            )
        case .softBreak:
            return NSAttributedString(string: " ", attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
            ])
        case .lineBreak:
            return NSAttributedString(string: "\n", attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
            ])
        case let .code(string), let .html(string):
            let controlAttributes: [NSAttributedString.Key: Any] = [
                .font: theme.fonts.codeInline,
                .backgroundColor: theme.colors.codeBackground.withAlphaComponent(0.05),
            ]
            let text = NSMutableAttributedString(string: string, attributes: [.foregroundColor: theme.colors.code])
            text.addAttributes(controlAttributes, range: .init(location: 0, length: text.length))
            return text
        case let .emphasis(children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: theme.colors.emphasis,
                ],
                range: NSRange(location: 0, length: ans.length)
            )
            return ans
        case let .strong(children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [.font: theme.fonts.bold],
                range: NSRange(location: 0, length: ans.length)
            )
            return ans
        case let .strikethrough(children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [.strikethroughStyle: NSUnderlineStyle.thick.rawValue],
                range: NSRange(location: 0, length: ans.length)
            )
            return ans
        case let .link(destination, children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, context: context, viewProvider: viewProvider) }.forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .link: destination,
                    .foregroundColor: theme.colors.highlight,
                ],
                range: NSRange(location: 0, length: ans.length)
            )
            return ans
        case let .image(source, _): // children => alternative text can be ignored?
            return NSAttributedString(
                string: source,
                attributes: [
                    .link: source,
                    .font: theme.fonts.body,
                    .foregroundColor: theme.colors.body,
                ]
            )
        case let .math(content, replacementIdentifier):
            if let item = context.rendered[replacementIdentifier], let image = item.image {
                let baseFont = theme.fonts.body
                var attachmentSize = image.size
                let maxInlineHeight = baseFont.lineHeight
                let scaleThreshold = maxInlineHeight * 1.8
                let shouldClampHeight = attachmentSize.height <= scaleThreshold

                if shouldClampHeight, attachmentSize.height > maxInlineHeight {
                    let aspectRatio = attachmentSize.width / attachmentSize.height
                    attachmentSize = CGSize(width: maxInlineHeight * aspectRatio, height: maxInlineHeight)
                }

                let drawingAction = MarkdownLineDrawingAction { context, line, lineOrigin, usedRect in
                    var drawSize = attachmentSize
                    var scale: CGFloat = 1
                    let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
                    var runOffsetX: CGFloat = 0
                    for i in 0 ..< glyphRuns.count {
                        let run = glyphRuns[i] as! CTRun
                        let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                        if attributes[.contextIdentifier] as? String == replacementIdentifier {
                            break
                        }
                        let runWidth = CGFloat(CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil))
                        runOffsetX += runWidth
                    }

                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0
                    CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                    let availableHeight = ascent + descent
                    if shouldClampHeight, availableHeight > 0, drawSize.height > availableHeight {
                        scale = min(scale, availableHeight / drawSize.height)
                    }

                    let availableWidth = max(0, usedRect.width - runOffsetX)
                    if availableWidth > 0, drawSize.width > availableWidth {
                        scale = min(scale, availableWidth / drawSize.width)
                    }

                    if scale != 1 {
                        drawSize = CGSize(width: drawSize.width * scale, height: drawSize.height * scale)
                    }

                    var rect = MarkdownAttachmentRenderer.attachmentRect(
                        size: drawSize,
                        line: line,
                        origin: lineOrigin,
                        offsetX: runOffsetX
                    )
                    let glyphBounds = usedRect.offsetBy(dx: lineOrigin.x - usedRect.minX, dy: lineOrigin.y - usedRect.maxY)
                    rect.origin.y = glyphBounds.midY - rect.height / 2

                    MarkdownAttachmentRenderer.drawImage(image, in: rect, context: context)
                }
                let attachment = MarkdownAttachment.hold(attrString: .init(string: content))
                attachment.size = attachmentSize
                var attributes: [NSAttributedString.Key: Any] = [
                    .contextIdentifier: replacementIdentifier,
                ]
                attributes.merge(attachment: attachment)
                attributes.merge(lineDrawing: drawingAction)
                return NSAttributedString(
                    string: MarkdownReplacementText.attachment,
                    attributes: attributes
                )
            } else {
                return NSAttributedString(
                    string: content,
                    attributes: [
                        .font: theme.fonts.codeInline,
                        .foregroundColor: theme.colors.code,
                        .backgroundColor: theme.colors.codeBackground.withAlphaComponent(0.05),
                    ]
                )
            }
        }
    }
}
