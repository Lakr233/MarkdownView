//
//  MarkdownLayoutManager.swift
//  MarkdownView
//
//  Created by GitHub Copilot on 2025/10/13.
//

import CoreText
import UIKit

final class MarkdownLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        guard let textStorage else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        enumerateLineFragments(forGlyphRange: glyphsToShow) { _, usedRect, _, fragmentGlyphRange, _ in
            let fragmentCharRange = self.characterRange(forGlyphRange: fragmentGlyphRange, actualGlyphRange: nil)
            let substring = textStorage.attributedSubstring(from: fragmentCharRange)
            var blockquoteContexts: [ObjectIdentifier: BlockquoteDrawingContext] = [:]
            substring.enumerateAttribute(.blockquoteContext, in: NSRange(location: 0, length: substring.length), options: []) { value, _, _ in
                guard let ctx = value as? BlockquoteDrawingContext else { return }
                let identifier = ObjectIdentifier(ctx)
                if blockquoteContexts[identifier] == nil {
                    blockquoteContexts[identifier] = ctx
                }
            }
            guard !blockquoteContexts.isEmpty else { return }

            let boundingBox = CGRect(
                x: origin.x + usedRect.minX,
                y: origin.y + usedRect.minY,
                width: usedRect.width,
                height: usedRect.height
            )
            guard !boundingBox.isNull, !boundingBox.isEmpty, !boundingBox.isInfinite else { return }

            for ctx in blockquoteContexts.values {
                ctx.accumulate(boundingBox)
            }
        }

        let characterRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        textStorage.enumerateAttribute(.markdownLineDrawing, in: characterRange, options: []) { value, range, _ in
            guard let action = value as? MarkdownLineDrawingAction else { return }
            let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }

            self.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, fragmentGlyphRange, _ in
                let fragmentCharRange = self.characterRange(forGlyphRange: fragmentGlyphRange, actualGlyphRange: nil)
                let substring = textStorage.attributedSubstring(from: fragmentCharRange)
                let line = CTLineCreateWithAttributedString(substring)
                let lineOrigin = CGPoint(
                    x: origin.x + usedRect.minX,
                    y: origin.y + usedRect.maxY
                )
                context.saveGState()
                action.handler(context, line, lineOrigin, usedRect)
                context.restoreGState()
            }
        }
    }
}
