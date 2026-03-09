//
//  WatchCodeBlockRenderer.swift
//  WatchMarkdownView
//

import CoreGraphics
import CoreText
import Foundation

enum WatchCodeBlockRenderer {
    struct Result {
        let image: CGImage?
        let size: CGSize
    }

    @MainActor
    static func render(
        code: String,
        theme: WatchMarkdownTheme,
        maxWidth: CGFloat,
        scale: CGFloat
    ) -> Result {
        let trimmed = trimTrailingCharacters(in: code, set: .whitespacesAndNewlines)
        let attributed = NSAttributedString(
            string: trimmed.isEmpty ? " " : trimmed,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: theme.codeFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: theme.codeColor,
            ]
        )

        let padding = theme.tableCellPadding
        let textWidth = max(1, maxWidth - padding * 2)
        let measured = measureSize(attributed, maxWidth: textWidth)
        let size = CGSize(
            width: min(maxWidth, max(padding * 2 + measured.width, 1)),
            height: max(padding * 2 + measured.height, theme.bodySize + padding * 2)
        )

        let pixelWidth = Int(ceil(size.width * scale))
        let pixelHeight = Int(ceil(size.height * scale))
        guard pixelWidth > 0, pixelHeight > 0 else {
            return Result(image: nil, size: .zero)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return Result(image: nil, size: .zero)
        }

        context.scaleBy(x: scale, y: scale)
        context.setAllowsAntialiasing(true)
        context.setShouldSmoothFonts(true)

        let backgroundRect = CGRect(origin: .zero, size: size)
        let backgroundPath = CGPath(
            roundedRect: backgroundRect,
            cornerWidth: 6,
            cornerHeight: 6,
            transform: nil
        )
        context.addPath(backgroundPath)
        context.setFillColor(theme.codeBackgroundColor)
        context.fillPath()

        let textRect = backgroundRect.insetBy(dx: padding, dy: padding)
        let path = CGPath(rect: textRect, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, context)

        return Result(image: context.makeImage(), size: size)
    }

    private static func measureSize(_ attrStr: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr as CFAttributedString)
        let constraints = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            constraints,
            nil
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    private static func trimTrailingCharacters(in string: String, set: CharacterSet) -> String {
        var copy = string
        while let last = copy.unicodeScalars.last, set.contains(last) {
            copy.removeLast()
        }
        return copy
    }
}
