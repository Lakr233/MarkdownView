//
//  InlineCode.swift
//  MarkdownView
//

import CoreText
import Foundation
import Litext

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension NSAttributedString.Key {
    /// Carries the `InlineCodeBackground` an inline code span is drawn on.
    static let inlineCodeBackground = NSAttributedString.Key("MarkdownView.inlineCodeBackground")
}

/// Inline code as a rounded pill: monospaced text a size smaller than the
/// body, so the line keeps the body's height, on a background inset a few
/// points past the text on either side.
@MainActor
enum InlineCode {
    /// Space between the pill's edge and the text, on each side.
    static let horizontalInset: CGFloat = 4
    /// How far the pill reaches above and below the code font's glyph box.
    static let verticalInset: CGFloat = 1
    static let cornerRadius: CGFloat = 5

    /// `<br>`, `<br/>` or `<br />`, which a table cell uses for a line break
    /// and which reads as one, not as code.
    nonisolated static func isLineBreak(_ html: String) -> Bool {
        let tag = html.lowercased().filter { !$0.isWhitespace }
        return tag == "<br>" || tag == "<br/>"
    }

    static func attributedString(_ string: String, theme: MarkdownTheme) -> NSAttributedString {
        let font = theme.fonts.codeInline
        let background = InlineCodeBackground(
            color: theme.colors.codeBackground,
            ascent: font.ascender,
            descent: abs(font.descender)
        )
        let result = NSMutableAttributedString()
        result.append(spacer(background: background, font: font))
        result.append(NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: theme.colors.code,
            .inlineCodeBackground: background,
        ]))
        result.append(spacer(background: background, font: font))
        return result
    }

    /// A blank attachment as wide as the inset. It copies as nothing, so the
    /// copied text is the code alone.
    private static func spacer(background: InlineCodeBackground, font: PlatformFont) -> NSAttributedString {
        let attachment = TextLabel.Attachment.hold(attrString: NSAttributedString())
        attachment.size = CGSize(width: horizontalInset, height: 0)
        return attachment.attributedString(attributes: [
            .font: font,
            .inlineCodeBackground: background,
        ])
    }
}

/// The pill behind one inline code span. Spans that look the same compare
/// equal, so a rebuilt document compares equal to the one it replaces.
final class InlineCodeBackground: NSObject {
    let color: PlatformColor
    let ascent: CGFloat
    let descent: CGFloat

    init(color: PlatformColor, ascent: CGFloat, descent: CGFloat) {
        self.color = color
        self.ascent = ascent
        self.descent = descent
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? InlineCodeBackground else { return false }
        return color.isEqual(other.color) && ascent == other.ascent && descent == other.descent
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(color)
        hasher.combine(ascent)
        hasher.combine(descent)
        return hasher.finalize()
    }
}

/// A text label that draws inline code on its pill.
///
/// The pill has to be drawn before the line's text: drawn afterwards it
/// either covers the glyphs or, composited beneath them, stacks up again on
/// every partial redraw. Labels showing markdown use this class; a plain
/// `TextLabelView` shows inline code without its background.
open class MarkdownTextLabelView: TextLabelView {
    override open func makeTextLayout(_ attributedText: NSAttributedString) -> TextLabel.Layout {
        InlineCodeLayout(attributedString: attributedText)
    }
}

private final class InlineCodeLayout: TextLabel.Layout {
    private lazy var hasInlineCode: Bool = {
        var found = false
        attributedString.enumerateAttribute(
            .inlineCodeBackground,
            in: NSRange(location: 0, length: attributedString.length)
        ) { value, _, stop in
            guard value != nil else { return }
            found = true
            stop.pointee = true
        }
        return found
    }()

    override func draw(line: CTLine, at index: Int, in context: CGContext) {
        if hasInlineCode {
            drawInlineCodeBackgrounds(of: line, in: context)
        }
        super.draw(line: line, at: index, in: context)
    }

    /// Fills one pill per code span on `line`, spanning its text and the
    /// spacers beside it. A spacer the line break left on a line by itself
    /// gets none.
    private func drawInlineCodeBackgrounds(of line: CTLine, in context: CGContext) {
        var spans: [(background: InlineCodeBackground, minX: CGFloat, maxX: CGFloat, holdsCode: Bool)] = []
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any]
            guard let background = attributes?[.inlineCodeBackground] as? InlineCodeBackground else { continue }
            let range = CTRunGetStringRange(run)
            let start = CTLineGetOffsetForStringIndex(line, range.location, nil)
            let end = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil)
            let holdsCode = attributes?[.litextAttachment] == nil
            if let index = spans.firstIndex(where: { $0.background === background }) {
                spans[index].minX = min(spans[index].minX, start, end)
                spans[index].maxX = max(spans[index].maxX, start, end)
                spans[index].holdsCode = spans[index].holdsCode || holdsCode
            } else {
                spans.append((background, min(start, end), max(start, end), holdsCode))
            }
        }
        guard !spans.isEmpty else { return }

        // CoreText space: the text position is the line's baseline origin.
        let origin = context.textPosition
        context.saveGState()
        defer { context.restoreGState() }
        for span in spans where span.holdsCode && span.minX < span.maxX {
            let background = span.background
            let rect = CGRect(
                x: origin.x + span.minX,
                y: origin.y - background.descent - InlineCode.verticalInset,
                width: span.maxX - span.minX,
                height: background.ascent + background.descent + InlineCode.verticalInset * 2
            )
            let radius = min(InlineCode.cornerRadius, rect.height / 2, rect.width / 2)
            context.setFillColor(background.color.cgColor)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
        }
        context.textPosition = origin
    }
}
