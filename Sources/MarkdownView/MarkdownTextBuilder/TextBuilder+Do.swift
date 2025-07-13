//
//  TextBuilder+Do.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import CoreText
import Foundation
import UIKit

private let kImageConfiguration = UIImage.SymbolConfiguration(scale: .small)
private let kCheckedBoxImage: UIImage = .init(systemName: "checkmark.square.fill", withConfiguration: kImageConfiguration) ?? .init()
private let kUncheckedBoxImage = UIImage(systemName: "square", withConfiguration: kImageConfiguration) ?? .init()

extension TextBuilder {
    @inline(__always)
    static func lineBoundingBox(_ line: CTLine, lineOrigin: CGPoint) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        return .init(x: lineOrigin.x, y: lineOrigin.y - descent, width: width, height: ascent + descent)
    }

    static func build(view: MarkdownTextView, viewProvider: ReusableViewProvider) -> BuildResult {
        let context: MarkdownTextView.PreprocessContent = view.document
        let theme: MarkdownTheme = view.theme

        return TextBuilder(nodes: context.blocks, context: context, viewProvider: viewProvider)
            .withTheme(theme)
            .withBulletDrawing { context, line, lineOrigin, depth in
                let radius: CGFloat = 3
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)

                var textColor = theme.colors.body
                if let firstRun = line.glyphRuns().first,
                   let attributes = CTRunGetAttributes(firstRun) as? [NSAttributedString.Key: Any],
                   let color = attributes[.foregroundColor] as? UIColor
                {
                    textColor = color
                }

                context.setStrokeColor(textColor.cgColor)
                context.setFillColor(textColor.cgColor)
                let rect = CGRect(
                    x: boundingBox.minX - 16,
                    y: boundingBox.midY - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                if depth == 0 {
                    context.fillEllipse(in: rect)
                } else if depth == 1 {
                    context.strokeEllipse(in: rect)
                } else {
                    context.fill(rect)
                }
            }
            .withNumberedDrawing { context, line, lineOrigin, index, indent, size in
                var text = "\(index)."
                while text.count < size + 1 {
                    text = " " + text
                }

                var textColor = theme.colors.body
                if let firstRun = line.glyphRuns().first,
                   let attributes = CTRunGetAttributes(firstRun) as? [NSAttributedString.Key: Any],
                   let color = attributes[.foregroundColor] as? UIColor
                {
                    textColor = color
                }

                let string = NSAttributedString(string: text, attributes: [
                    .font: theme.fonts.codeInline,
                    .foregroundColor: textColor,
                ])
                let rect = lineBoundingBox(line, lineOrigin: lineOrigin).offsetBy(dx: -indent, dy: 0)
                let path = CGPath(rect: rect, transform: nil)
                let framesetter = CTFramesetterCreateWithAttributedString(string)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, string.length), path, nil)
                CTFrameDraw(frame, context)
            }
            .withCheckboxDrawing { context, line, lineOrigin, isChecked in
                let rect = lineBoundingBox(line, lineOrigin: lineOrigin).offsetBy(dx: -20, dy: 0)
                let image = if isChecked { kCheckedBoxImage } else { kUncheckedBoxImage }
                guard let cgImage = image.cgImage else { return }
                let imageSize = image.size
                let targetRect: CGRect = .init(
                    x: rect.minX,
                    y: rect.midY - imageSize.height / 2,
                    width: imageSize.width,
                    height: imageSize.height
                )

                // Get the current color from the text
                var textColor = theme.colors.body
                if let firstRun = line.glyphRuns().first,
                   let attributes = CTRunGetAttributes(firstRun) as? [NSAttributedString.Key: Any],
                   let color = attributes[.foregroundColor] as? UIColor
                {
                    textColor = color
                }

                context.clip(to: targetRect, mask: cgImage)
                context.setFillColor(textColor.withAlphaComponent(0.24).cgColor)
                context.fill(targetRect)
            }
            .withThematicBreakDrawing { [weak view] context, line, lineOrigin in
                guard let view else { return }
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)

                context.setLineWidth(1)
                context.setStrokeColor(UIColor.label.withAlphaComponent(0.1).cgColor)
                context.move(to: .init(x: boundingBox.minX, y: boundingBox.midY))
                context.addLine(to: .init(x: boundingBox.minX + view.bounds.width, y: boundingBox.midY))
                context.strokePath()
            }
            .withCodeDrawing { [weak view] _, line, lineOrigin in
                guard let view else { return }
                guard let firstRun = line.glyphRuns().first else { return }
                let attributes = firstRun.attributes
                guard let codeView = attributes[.contextView] as? CodeView else {
                    assertionFailure()
                    return
                }

                if codeView.superview != view { view.addSubview(codeView) }
                let intrinsicContentSize = codeView.intrinsicContentSize
                let lineBoundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                var leftIndent: CGFloat = 0
                if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                    leftIndent = paragraphStyle.headIndent
                }

                codeView.frame = .init(
                    origin: .init(x: lineOrigin.x + leftIndent, y: view.bounds.height - lineBoundingBox.maxY),
                    size: .init(width: view.bounds.width - leftIndent, height: intrinsicContentSize.height)
                )
                codeView.previewAction = view.codePreviewHandler
            }
            .withTableDrawing { [weak view] _, line, lineOrigin in
                guard let view else { return }
                guard let firstRun = line.glyphRuns().first else { return }
                let attributes = firstRun.attributes
                guard let tableView = attributes[.contextView] as? TableView else {
                    assertionFailure()
                    return
                }

                if tableView.superview != view { view.addSubview(tableView) }
                let lineBoundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                let intrinsicContentSize = tableView.intrinsicContentSize
                var leftIndent: CGFloat = 0
                if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                    leftIndent = paragraphStyle.headIndent
                }

                tableView.frame = .init(
                    x: lineOrigin.x + leftIndent,
                    y: view.bounds.height - lineBoundingBox.maxY,
                    width: view.bounds.width - leftIndent,
                    height: intrinsicContentSize.height
                )
            }
            .withBlockquoteDrawing { [weak view] context, line, lineOrigin, depth in
                guard let view else { return }
                let blockquoteTheme = theme.blockquote
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)

                var lineSpacing: CGFloat = 4
                var paragraphSpacing: CGFloat = 0
                var isStart = false
                var isEnd = false

                let lineRange = CTLineGetStringRange(line)
                if lineRange.location < view.textView.attributedText.length {
                    let attrs = view.textView.attributedText.attributes(at: lineRange.location, effectiveRange: nil)

                    if let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                        lineSpacing = paragraphStyle.lineSpacing
                        paragraphSpacing = paragraphStyle.paragraphSpacing
                    }

                    // Check for blockquote boundaries
                    for i in lineRange.location ..< min(lineRange.location + lineRange.length, view.textView.attributedText.length) {
                        let charAttrs = view.textView.attributedText.attributes(at: i, effectiveRange: nil)
                        isStart = isStart || (charAttrs[.isBlockquoteStart] as? Bool ?? false)
                        isEnd = isEnd || (charAttrs[.isBlockquoteEnd] as? Bool ?? false)
                    }
                }

                // Calculate vertical bar dimensions
                let overlapExtension: CGFloat = 10.0
                let topExtension = isStart ? lineSpacing : (lineSpacing + overlapExtension)
                let bottomExtension = isEnd ? lineSpacing : (lineSpacing + paragraphSpacing + overlapExtension)

                let barTop = boundingBox.maxY + topExtension
                let barBottom = boundingBox.minY - bottomExtension
                let barHeight = barTop - barBottom

                // Draw vertical bars for each nesting level
                let textMargin = boundingBox.minX - (CGFloat(depth + 1) * blockquoteTheme.leftIndent)
                for level in 0 ... depth {
                    let barX = textMargin + CGFloat(level) * blockquoteTheme.leftIndent
                    let alpha = level == 0 ? 1.0 : max(0.3, 0.6 - CGFloat(level - 1) * 0.15)

                    context.setFillColor(blockquoteTheme.barColor.withAlphaComponent(alpha).cgColor)
                    context.fill(CGRect(x: barX, y: barBottom, width: blockquoteTheme.barWidth, height: barHeight))
                }
            }
            .build()
    }
}
