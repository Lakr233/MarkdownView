//
//  WatchInlineRenderer.swift
//  WatchMarkdownView
//
//  Converts MarkdownInlineNode AST to NSAttributedString using CoreText attributes.
//  No UIKit or AppKit — only Foundation + CoreText.
//

import CoreText
import Foundation
import MarkdownParser

// MARK: - Array extension

extension [MarkdownInlineNode] {
    func render(theme: WatchMarkdownTheme, baseFont: CTFont? = nil) -> NSAttributedString {
        let font = baseFont ?? theme.bodyFont
        let result = NSMutableAttributedString()
        for node in self {
            result.append(node.render(theme: theme, baseFont: font))
        }
        return result
    }
}

// MARK: - Node rendering

extension MarkdownInlineNode {
    func render(theme: WatchMarkdownTheme, baseFont: CTFont) -> NSAttributedString {
        switch self {
        case let .text(string):
            return NSAttributedString(string: string, attributes: baseAttributes(font: baseFont, theme: theme))

        case .softBreak:
            return NSAttributedString(string: " ", attributes: baseAttributes(font: baseFont, theme: theme))

        case .lineBreak:
            return NSAttributedString(string: "\n", attributes: baseAttributes(font: baseFont, theme: theme))

        case let .code(string), let .html(string):
            return NSAttributedString(string: string, attributes: codeAttributes(theme: theme))

        case let .emphasis(children):
            let derived = derivedFont(from: baseFont, adding: .italicTrait, fallback: theme.italicFont)
            return children.render(theme: theme, baseFont: derived)

        case let .strong(children):
            let derived = derivedFont(from: baseFont, adding: .boldTrait, fallback: theme.boldFont)
            return children.render(theme: theme, baseFont: derived)

        case let .strikethrough(children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, baseFont: baseFont) }.forEach { ans.append($0) }
            // kCTStrikethroughStyleAttributeName is CoreText-native and works on watchOS.
            // CTFrameDraw does not natively draw strikethrough decorations, but the attribute
            // is stored for potential custom rendering. Use underline as a visible fallback.
            ans.addAttribute(
                kCTUnderlineStyleAttributeName as NSAttributedString.Key,
                value: CTUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: ans.length)
            )
            return ans

        case let .link(destination, children):
            let ans = NSMutableAttributedString()
            children.map { $0.render(theme: theme, baseFont: baseFont) }.forEach { ans.append($0) }
            let range = NSRange(location: 0, length: ans.length)
            ans.addAttribute(NSAttributedString.Key.link, value: destination, range: range)
            ans.addAttribute(
                kCTForegroundColorAttributeName as NSAttributedString.Key,
                value: theme.linkColor,
                range: range
            )
            return ans

        case let .image(source, _):
            // Images can't be loaded on watchOS here; show as bracketed URL
            return NSAttributedString(string: "[\(source)]", attributes: [
                kCTFontAttributeName as NSAttributedString.Key: baseFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: theme.linkColor,
            ])

        case let .math(content, _):
            // No math rendering on watchOS — display raw LaTeX as inline code
            return NSAttributedString(string: content, attributes: codeAttributes(theme: theme))
        }
    }
}

// MARK: - Attribute helpers

private func baseAttributes(font: CTFont, theme: WatchMarkdownTheme) -> [NSAttributedString.Key: Any] {
    [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: theme.textColor,
    ]
}

private func codeAttributes(theme: WatchMarkdownTheme) -> [NSAttributedString.Key: Any] {
    [
        kCTFontAttributeName as NSAttributedString.Key: theme.codeFont,
        kCTForegroundColorAttributeName as NSAttributedString.Key: theme.codeColor,
    ]
}

/// Derives a CTFont from a base font by adding symbolic traits, with a fallback.
private func derivedFont(from base: CTFont, adding trait: CTFontSymbolicTraits, fallback: CTFont) -> CTFont {
    let size = CTFontGetSize(base)
    // Preserve existing traits + add the new one
    let existing = CTFontGetSymbolicTraits(base)
    let combined = CTFontSymbolicTraits(rawValue: existing.rawValue | trait.rawValue)
    return CTFontCreateCopyWithSymbolicTraits(base, size, nil, combined, combined) ?? fallback
}
