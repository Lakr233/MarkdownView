import CoreText
import UIKit

enum MarkdownAttachmentRenderer {
    private static func resolvedMetrics(for line: CTLine) -> (ascent: CGFloat, descent: CGFloat, leading: CGFloat) {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        return (ascent, descent, leading)
    }

    private static func resolvedExtents(for line: CTLine, origin: CGPoint) -> (top: CGFloat, bottom: CGFloat) {
        let runs = CTLineGetGlyphRuns(line) as NSArray
        var minTop = CGFloat.greatestFiniteMagnitude
        var maxBottom = -CGFloat.greatestFiniteMagnitude

        for index in 0 ..< runs.count {
            let run = runs[index] as! CTRun
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), &ascent, &descent, nil)
            minTop = min(minTop, origin.y - ascent)
            maxBottom = max(maxBottom, origin.y + descent)
        }

        if minTop <= maxBottom {
            return (minTop, maxBottom)
        }

        let metrics = resolvedMetrics(for: line)
        return (origin.y - metrics.ascent, origin.y + metrics.descent)
    }

    static func drawTemplateImage(
        _ image: UIImage,
        in rect: CGRect,
        tint color: UIColor,
        context: CGContext
    ) {
        guard let cgImage = image.cgImage else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        let drawingRect = CGRect(origin: .zero, size: rect.size)
        context.clip(to: drawingRect, mask: cgImage)
        context.setFillColor(color.cgColor)
        context.fill(drawingRect)
        context.restoreGState()
    }

    static func drawImage(
        _ image: UIImage,
        in rect: CGRect,
        context: CGContext
    ) {
        guard let cgImage = image.cgImage else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    static func attachmentRect(
        size: CGSize,
        line: CTLine,
        origin: CGPoint,
        offsetX: CGFloat = 0
    ) -> CGRect {
        let extents = resolvedExtents(for: line, origin: origin)
        let centerY = (extents.top + extents.bottom) / 2
        return CGRect(
            x: origin.x + offsetX,
            y: centerY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func firstTextRunMidY(line: CTLine, origin: CGPoint) -> CGFloat? {
        let runs = CTLineGetGlyphRuns(line) as NSArray
        for index in 0 ..< runs.count {
            let run = runs[index] as! CTRun
            let attributes = run.attributes
            if attributes[.markdownAttachment] != nil {
                continue
            }
            if attributes[.markdownLineDrawing] != nil {
                continue
            }
            if CTRunGetGlyphCount(run) == 0 {
                continue
            }
            let bounds = CTRunGetImageBounds(run, nil, CFRange(location: 0, length: 0))
            guard !bounds.isNull, bounds.height > 0 else { continue }
            return origin.y - bounds.midY
        }
        return nil
    }
}
