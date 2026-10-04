//
//  InlineNode+Render.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import Foundation
import Litext
import LRUCache
import MarkdownParser
import SwiftMath
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension [MarkdownInlineNode] {
    @MainActor
    func render(
        theme: MarkdownTheme,
        context: MarkdownContent,
        decoration: TextBuilder.InlineTextDecoration? = nil,
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for node in self {
            result.append(node.render(
                theme: theme,
                context: context,
                decoration: decoration,
            ))
        }
        return result
    }
}

extension MarkdownInlineNode {
    @MainActor
    func render(
        theme: MarkdownTheme,
        context: MarkdownContent,
        decoration: TextBuilder.InlineTextDecoration? = nil,
    ) -> NSAttributedString {
        assert(Thread.isMainThread)
        switch self {
        case let .text(string):
            // Past the cache, never into it: a decoration may carry an
            // attachment, and an attachment holds a view, which belongs to the
            // one text view it was built for rather than to every view that
            // draws the same words.
            let rendered = context.cachedBodyText(string, theme: theme)
            return decoration?(rendered) ?? rendered
        case .softBreak:
            return context.cachedBodyText(" ", theme: theme)
        case .lineBreak:
            return context.cachedBodyText("\n", theme: theme)
        case let .html(string) where InlineCode.isLineBreak(string):
            return NSMutableAttributedString(string: "\n", attributes: [.font: theme.fonts.body])
        case let .code(string), let .html(string):
            return NSMutableAttributedString(attributedString: InlineCode.attributedString(string, theme: theme))
        case let .emphasis(children):
            let ans = NSMutableAttributedString()
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: theme.colors.emphasis,
                ],
                range: NSRange(location: 0, length: ans.length),
            )
            return ans
        case let .strong(children):
            let ans = NSMutableAttributedString()
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
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
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
            ans.addAttributes(
                [.strikethroughStyle: NSUnderlineStyle.thick.rawValue],
                range: NSRange(location: 0, length: ans.length),
            )
            return ans
        case let .link(destination, children):
            let ans = NSMutableAttributedString()
            children
                .map { $0.render(theme: theme, context: context, decoration: decoration) }
                .forEach { ans.append($0) }
            ans.addAttributes(
                [
                    .link: destination,
                    .foregroundColor: theme.colors.highlight,
                ],
                range: NSRange(location: 0, length: ans.length),
            )
            return ans
        case let .image(source, _): // children => alternative text can be ignored?
            return NSAttributedString(
                string: source,
                attributes: [
                    .link: source,
                    .font: theme.fonts.body,
                    .foregroundColor: theme.colors.body,
                ],
            )
        case let .math(content, replacementIdentifier):
            // Get LaTeX content from rendered context or fallback to raw content
            let latexContent = context.rendered[replacementIdentifier]?.text ?? content

            if let item = context.rendered[replacementIdentifier], let image = item.image {
                let cacheKey = InlineMathCache.Key(
                    image: ObjectIdentifier(image),
                    identifier: replacementIdentifier,
                    latex: latexContent,
                    color: theme.colors.body,
                )
                if let cached = InlineMathCache.storage.value(forKey: cacheKey) {
                    return cached
                }
                let imageSize = image.size
                let textColor = theme.colors.body
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
                        height: drawSize.height,
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
                            // Resolve the theme's colour at draw time for dynamic appearance updates
                            context.clip(to: rect, mask: cgImage)
                            context.setFillColor(textColor.cgColor)
                            context.fill(rect)
                        } else {
                            assertionFailure()
                        }
                    #endif

                    context.restoreGState()
                }
                // The image is drawn standing on the baseline, so it reserves its
                // height above the baseline and nothing below it.
                let attachment = TextLabel.Attachment.hold(
                    attrString: .init(string: latexContent),
                    size: imageSize,
                    descent: 0,
                )

                let attributes: [NSAttributedString.Key: Any] = [
                    .litextAttachment: attachment,
                    .litextLineDrawingAction: drawingCallback,
                    kCTRunDelegateAttributeName as NSAttributedString.Key: attachment.runDelegate,
                    .contextIdentifier: replacementIdentifier,
                    .mathLatexContent: latexContent, // Store LaTeX content for on-demand rendering
                ]

                let rendered = NSAttributedString(
                    string: TextLabel.Attachment.replacementText,
                    attributes: attributes,
                )
                InlineMathCache.storage.setValue(rendered, forKey: cacheKey)
                return rendered
            } else {
                // Fallback: render failed, show original LaTeX as inline code
                return InlineCode.attributedString(latexContent, theme: theme)
            }
        }
    }
}

/// Rendered inline math, shared by every content.
///
/// A rebuilt document makes its math again, and the drawing action and run
/// delegate it carries compare by identity, so a paragraph holding math never
/// compared equal to itself: the label typeset it again on every streamed
/// update. The same formula, image and colour now yield the same string.
@MainActor
private enum InlineMathCache {
    /// The image is one `MathRenderer` cached for the formula; the entry keeps
    /// it alive, so its identifier is not reused while the entry exists.
    struct Key: Hashable, @unchecked Sendable {
        let image: ObjectIdentifier
        let identifier: String
        let latex: String
        let color: PlatformColor
    }

    static let storage = LRUCache<Key, NSAttributedString>(countLimit: 512)
}
