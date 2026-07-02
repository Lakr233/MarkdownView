//
//  InlineNode+Render.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import Litext
import MarkdownParser
import SwiftMath
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension [MarkdownInlineNode] {
    @MainActor
    func render(theme: MarkdownTheme, context: MarkdownTextView.PreprocessedContent, viewProvider: ReusableViewProvider) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for node in self {
            result.append(node.render(theme: theme, context: context, viewProvider: viewProvider))
        }
        return result
    }
}

extension MarkdownInlineNode {
    @MainActor
    func render(theme: MarkdownTheme, context: MarkdownTextView.PreprocessedContent, viewProvider: ReusableViewProvider) -> NSAttributedString {
        assert(Thread.isMainThread)
        switch self {
        case let .text(string):
            return context.cachedBodyText(string, theme: theme)
        case .softBreak:
            return context.cachedBodyText(" ", theme: theme)
        case .lineBreak:
            return context.cachedBodyText("\n", theme: theme)
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
            ans.enumerateAttribute(.font, in: NSRange(location: 0, length: ans.length)) { value, range, _ in
                #if canImport(UIKit)
                    guard let font = value as? UIFont, font != theme.fonts.body else {
                        ans.addAttribute(.font, value: theme.fonts.bold, range: range)
                        return
                    }
                    let traits = font.fontDescriptor.symbolicTraits.union(.traitBold)
                    let boldFont = font.fontDescriptor.withSymbolicTraits(traits)
                        .map { UIFont(descriptor: $0, size: 0) } ?? font
                    ans.addAttribute(.font, value: boldFont, range: range)
                #elseif canImport(AppKit)
                    guard let font = value as? NSFont, font != theme.fonts.body else {
                        ans.addAttribute(.font, value: theme.fonts.bold, range: range)
                        return
                    }
                    ans.addAttribute(.font, value: font.bold, range: range)
                #endif
            }
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
            // Get LaTeX content from rendered context or fallback to raw content
            let latexContent = context.rendered[replacementIdentifier]?.text ?? content

            if let item = context.rendered[replacementIdentifier], let image = item.image {
                let imageSize = image.size
                let contextKey = NSAttributedString.Key.contextIdentifier.rawValue as CFString

                let drawingCallback = TextLabel.LineDrawingAction { context, line, lineOrigin in
                    let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
                    var runOffsetX: CGFloat = 0
                    for i in 0 ..< glyphRuns.count {
                        let run = glyphRuns[i] as! CTRun
                        let attributes = CTRunGetAttributes(run)
                        if let ptr = CFDictionaryGetValue(attributes, Unmanaged.passUnretained(contextKey).toOpaque()) {
                            let value = Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
                            if (value as? String) == replacementIdentifier {
                                break
                            }
                        }
                        runOffsetX += CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
                    }

                    var ascent: CGFloat = 0
                    var descent: CGFloat = 0
                    CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                    var drawSize = imageSize
                    if drawSize.height > ascent { // we only draw above the line
                        drawSize = CGSize(width: drawSize.width * (ascent / drawSize.height), height: ascent)
                    }

                    let rect = CGRect(
                        x: lineOrigin.x + runOffsetX,
                        y: lineOrigin.y,
                        width: drawSize.width,
                        height: drawSize.height
                    )

                    context.saveGState()

                    #if canImport(UIKit)
                        context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
                        context.scaleBy(x: 1, y: -1)
                        context.translateBy(x: 0, y: -rect.origin.y)
                        image.draw(in: rect)
                    #else
                        assert(image.isTemplate)
                        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            // Resolve label color at draw time for dynamic appearance updates
                            let labelColor = NSColor.labelColor.cgColor
                            context.clip(to: rect, mask: cgImage)
                            context.setFillColor(labelColor)
                            context.fill(rect)
                        } else {
                            assertionFailure()
                        }
                    #endif

                    context.restoreGState()
                }
                let attachment = TextLabel.Attachment.hold(attrString: .init(string: latexContent))
                // Litext's attachment run delegate reports ascent = 0.9 * size.height and
                // descent = 0.1 * size.height, so pad the height to keep the full image
                // above the baseline while the reserved width matches the drawn width.
                attachment.size = CGSize(width: imageSize.width, height: imageSize.height / 0.9)

                let attributes: [NSAttributedString.Key: Any] = [
                    .litextAttachment: attachment,
                    .litextLineDrawingAction: drawingCallback,
                    kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
                    .contextIdentifier: replacementIdentifier,
                    .mathLatexContent: latexContent, // Store LaTeX content for on-demand rendering
                ]

                return NSAttributedString(
                    string: TextLabel.Attachment.replacementText,
                    attributes: attributes
                )
            } else {
                // Fallback: render failed, show original LaTeX as inline code
                return NSAttributedString(
                    string: latexContent,
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
