//
//  WatchTableRenderer.swift
//  WatchMarkdownView
//
//  Renders markdown tables to CGImage via an offscreen CGContext.
//  Pure CoreText + CoreGraphics for draw-action based rendering.
//

import CoreGraphics
import CoreText
import Foundation
import LRUCache
import MarkdownParser

// MARK: - CoreGraphics renderer (pure, no SwiftUI)

enum WatchTableRenderer {
    struct Result {
        let image: CGImage?
        let size: CGSize
    }

    @MainActor
    private static let cache = LRUCache<Int, Result>(countLimit: 16)

    @MainActor
    static func render(
        rows: [RawTableRow],
        columnAlignments: [RawTableColumnAlignment],
        theme: WatchMarkdownTheme,
        maxWidth: CGFloat,
        scale: CGFloat
    ) -> Result {
        var hasher = Hasher()
        hasher.combine(rows)
        hasher.combine(columnAlignments)
        hasher.combine(maxWidth)
        hasher.combine(scale)
        hasher.combine(theme.bodySize)
        hasher.combine(theme.codeScale)
        hasher.combine(theme.tableCellPadding)
        hasher.combine(theme.tableMaxColumnWidth)
        hashColor(theme.textColor, into: &hasher)
        hashColor(theme.linkColor, into: &hasher)
        hashColor(theme.accentColor, into: &hasher)
        hashColor(theme.codeColor, into: &hasher)
        hashColor(theme.tableBorderColor, into: &hasher)
        hashColor(theme.tableHeaderBackgroundColor, into: &hasher)
        hashColor(theme.tableStripeColor, into: &hasher)
        let key = hasher.finalize()
        if let cached = cache.value(forKey: key) {
            return cached
        }
        let result = renderImage(
            rows: rows,
            columnAlignments: columnAlignments,
            theme: theme,
            maxWidth: maxWidth,
            scale: scale
        )
        cache.setValue(result, forKey: key)
        return result
    }

    @MainActor
    private static func renderImage(
        rows: [RawTableRow],
        columnAlignments: [RawTableColumnAlignment],
        theme: WatchMarkdownTheme,
        maxWidth: CGFloat,
        scale: CGFloat
    ) -> Result {
        guard !rows.isEmpty else { return Result(image: nil, size: .zero) }

        let padding = theme.tableCellPadding
        let borderWidth: CGFloat = 1
        let numCols = rows.first?.cells.count ?? 0
        let numRows = rows.count
        guard numCols > 0 else { return Result(image: nil, size: .zero) }

        // MARK: Build attributed strings

        var cellStrings: [[NSAttributedString]] = []
        for (rowIdx, row) in rows.enumerated() {
            let font = rowIdx == 0 ? theme.boldFont : theme.bodyFont
            cellStrings.append(row.cells.map { cell in
                cell.content.render(theme: theme, baseFont: font)
            })
        }

        for c in 0 ..< numCols {
            let paragraphStyle: CTParagraphStyle
            switch columnAlignments[safe: c] ?? .none {
            case .center:
                paragraphStyle = centerParagraphStyle
            case .right:
                paragraphStyle = rightParagraphStyle
            default:
                continue
            }
            for r in 0 ..< cellStrings.count where c < cellStrings[r].count {
                let mutable = NSMutableAttributedString(attributedString: cellStrings[r][c])
                mutable.addAttribute(
                    kCTParagraphStyleAttributeName as NSAttributedString.Key,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: mutable.length)
                )
                cellStrings[r][c] = mutable
            }
        }

        let cellFramesetters: [[CTFramesetter?]] = cellStrings.map { row in
            row.map { attrStr in
                guard attrStr.length > 0 else { return nil }
                return CTFramesetterCreateWithAttributedString(attrStr as CFAttributedString)
            }
        }

        // MARK: Measure cells

        let availableForCells = maxWidth - borderWidth * CGFloat(numCols + 1)
        let minInnerWidth: CGFloat = 8
        let maxColWidth = max(
            padding * 2 + minInnerWidth,
            min(theme.tableMaxColumnWidth, availableForCells / CGFloat(numCols))
        )
        let innerWidth = maxColWidth - padding * 2

        var colWidths = Array(repeating: CGFloat(0), count: numCols)
        var rowHeights = Array(repeating: CGFloat(0), count: numRows)

        for r in 0 ..< numRows {
            for c in 0 ..< numCols {
                guard r < cellFramesetters.count, c < cellFramesetters[r].count else { continue }
                let measured = measureSize(cellFramesetters[r][c], maxWidth: max(1, innerWidth))
                colWidths[c] = max(colWidths[c], min(measured.width + padding * 2, maxColWidth))
                rowHeights[r] = max(rowHeights[r], measured.height + padding * 2)
            }
        }

        let totalWidth = colWidths.reduce(0, +) + borderWidth * CGFloat(numCols + 1)
        let totalHeight = rowHeights.reduce(0, +) + borderWidth * CGFloat(numRows + 1)

        // MARK: Create context

        let pw = Int(ceil(totalWidth * scale))
        let ph = Int(ceil(totalHeight * scale))
        guard pw > 0, ph > 0 else { return Result(image: nil, size: .zero) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: pw, height: ph,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return Result(image: nil, size: .zero) }

        ctx.scaleBy(x: scale, y: scale)
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldSmoothFonts(true)

        // MARK: Draw backgrounds + text (Y-up coords)

        var topY = totalHeight - borderWidth

        for r in 0 ..< numRows {
            let rowH = rowHeights[r]
            let rowBottomY = topY - rowH

            if r == 0 {
                ctx.setFillColor(theme.tableHeaderBackgroundColor)
                ctx.fill(CGRect(x: borderWidth, y: rowBottomY,
                                width: totalWidth - borderWidth * 2, height: rowH))
            } else if r % 2 == 0 {
                ctx.setFillColor(theme.tableStripeColor)
                ctx.fill(CGRect(x: borderWidth, y: rowBottomY,
                                width: totalWidth - borderWidth * 2, height: rowH))
            }

            var leftX = borderWidth
            for c in 0 ..< numCols {
                guard r < cellFramesetters.count, c < cellFramesetters[r].count else { continue }
                let colW = colWidths[c]
                let cellRect = CGRect(
                    x: leftX + padding,
                    y: rowBottomY + padding,
                    width: colW - padding * 2,
                    height: rowH - padding * 2
                )
                drawText(cellFramesetters[r][c], in: cellRect, ctx: ctx)
                leftX += colW + borderWidth
            }

            topY -= rowH + borderWidth
        }

        // MARK: Draw grid

        ctx.setStrokeColor(theme.tableBorderColor)
        ctx.setLineWidth(1.0 / scale)

        var lineY = totalHeight
        for r in 0 ... numRows {
            ctx.move(to: CGPoint(x: 0, y: lineY))
            ctx.addLine(to: CGPoint(x: totalWidth, y: lineY))
            if r < numRows { lineY -= rowHeights[r] + borderWidth }
        }

        var lineX: CGFloat = 0
        for c in 0 ... numCols {
            ctx.move(to: CGPoint(x: lineX, y: 0))
            ctx.addLine(to: CGPoint(x: lineX, y: totalHeight))
            if c < numCols { lineX += colWidths[c] + borderWidth }
        }
        ctx.strokePath()

        guard let cgImage = ctx.makeImage() else { return Result(image: nil, size: .zero) }
        return Result(image: cgImage, size: CGSize(width: totalWidth, height: totalHeight))
    }

    // MARK: - Text drawing

    private static func drawText(
        _ framesetter: CTFramesetter?,
        in rect: CGRect,
        ctx: CGContext
    ) {
        guard let framesetter, rect.width > 0, rect.height > 0 else { return }

        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, ctx)
    }

    private static func hashColor(_ color: CGColor, into hasher: inout Hasher) {
        hasher.combine(color.components ?? [])
        hasher.combine((color.colorSpace?.name).map { $0 as String })
    }

    private static func measureSize(_ framesetter: CTFramesetter?, maxWidth: CGFloat) -> CGSize {
        guard let framesetter else { return .zero }
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

    @MainActor
    private static let centerParagraphStyle = makeParagraphStyle(for: .center)

    @MainActor
    private static let rightParagraphStyle = makeParagraphStyle(for: .right)

    private static func makeParagraphStyle(for alignment: RawTableColumnAlignment) -> CTParagraphStyle {
        var value: CTTextAlignment = switch alignment {
        case .center:
            .center
        case .right:
            .right
        default:
            .left
        }

        return withUnsafePointer(to: &value) { pointer in
            var setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: pointer
            )
            return CTParagraphStyleCreate(&setting, 1)
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
