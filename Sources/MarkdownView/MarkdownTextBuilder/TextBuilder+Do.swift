//
//  TextBuilder+Do.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import CoreText
import Foundation
import UIKit

private func builtinSystemImage(_ name: String, size: CGFloat = 16) -> UIImage {
    guard let image = UIImage(
        systemName: name,
        withConfiguration: UIImage.SymbolConfiguration(scale: .small)
    ) else { return .init() }
    let templateImage = image.withTintColor(.label, renderingMode: .alwaysTemplate)
    return templateImage.resized(to: .init(width: size, height: size))
}

private let kCheckedBoxImage = builtinSystemImage("checkmark.square.fill")
private let kUncheckedBoxImage = builtinSystemImage("square")

private func kNumberCircleImage(_ number: Int) -> UIImage {
    builtinSystemImage("\(number).circle.fill")
}

extension TextBuilder {
    @inline(__always)
    static func lineBoundingBox(_ line: CTLine, lineOrigin: CGPoint) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        let height = ascent + descent
        return .init(x: lineOrigin.x, y: lineOrigin.y - descent - height, width: width, height: height)
    }

    static func build(view: MarkdownTextView, viewProvider: ReusableViewProvider) -> BuildResult {
        let context: MarkdownTextView.PreprocessedContent = view.document
        let theme: MarkdownTheme = view.theme

        @discardableResult
        func populateContextColorFromFirstRun(context: CGContext, line: CTLine) -> UIColor {
            var textColor = theme.colors.body
            if let firstRun = line.glyphRuns().first,
               let attributes = CTRunGetAttributes(firstRun) as? [NSAttributedString.Key: Any],
               let color = attributes[.foregroundColor] as? UIColor
            {
                textColor = color
            }
            context.setStrokeColor(textColor.cgColor)
            context.setFillColor(textColor.cgColor)
            return textColor
        }

        func blockquoteContext(in line: CTLine) -> BlockquoteDrawingContext? {
            for run in line.glyphRuns() {
                let attributes = run.attributes
                if let context = attributes[.blockquoteContext] as? BlockquoteDrawingContext {
                    return context
                }
            }
            return nil
        }

        return TextBuilder(nodes: context.blocks, context: context, viewProvider: viewProvider)
            .withTheme(theme)
            .withBulletDrawing { context, line, lineOrigin, _, depth in
                let radius: CGFloat = 3
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)
                populateContextColorFromFirstRun(context: context, line: line)
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
            .withNumberedDrawing { context, line, lineOrigin, _, num in
                let rect = lineBoundingBox(line, lineOrigin: lineOrigin)
                    .offsetBy(dx: -16, dy: 0)
                    .offsetBy(dx: -8, dy: 0)
                let image = kNumberCircleImage(num)
                let imageSize = image.size
                let targetRect: CGRect = .init(
                    x: rect.minX,
                    y: rect.midY - imageSize.height / 2,
                    width: imageSize.width,
                    height: imageSize.height
                )
                let textColor = populateContextColorFromFirstRun(context: context, line: line)
                MarkdownAttachmentRenderer.drawTemplateImage(image, in: targetRect, tint: textColor, context: context)
            }
            .withCheckboxDrawing { context, line, lineOrigin, _, isChecked in
                let rect = lineBoundingBox(line, lineOrigin: lineOrigin)
                    .offsetBy(dx: -16, dy: 0)
                    .offsetBy(dx: -8, dy: 0)
                let image = if isChecked { kCheckedBoxImage } else { kUncheckedBoxImage }
                let imageSize = image.size
                let targetRect: CGRect = .init(
                    x: rect.minX,
                    y: rect.midY - imageSize.height / 2,
                    width: imageSize.width,
                    height: imageSize.height
                )
                let textColor = populateContextColorFromFirstRun(context: context, line: line)
                MarkdownAttachmentRenderer.drawTemplateImage(image, in: targetRect, tint: textColor.withAlphaComponent(0.24), context: context)
            }
            .withThematicBreakDrawing { [weak view] context, _, lineOrigin, usedRect in
                guard let view else { return }
                let boundingBox = usedRect.offsetBy(dx: lineOrigin.x - usedRect.minX, dy: lineOrigin.y - usedRect.maxY)

                context.setLineWidth(1)
                context.setStrokeColor(UIColor.label.withAlphaComponent(0.1).cgColor)
                context.move(to: .init(x: boundingBox.minX, y: boundingBox.midY))
                context.addLine(to: .init(x: boundingBox.minX + view.bounds.width, y: boundingBox.midY))
                context.strokePath()
            }
            .withCodeDrawing { [weak view] _, line, _, _ in
                guard let view else { return }
                guard let firstRun = line.glyphRuns().first else { return }
                let attributes = firstRun.attributes
                guard let codeView = attributes[.contextView] as? CodeView else {
                    assertionFailure()
                    return
                }
                codeView.previewAction = view.codePreviewHandler
            }
            .withTableDrawing { _, line, _, _ in
                guard let firstRun = line.glyphRuns().first else { return }
                let attributes = firstRun.attributes
                guard attributes[.contextView] is TableView else {
                    assertionFailure()
                    return
                }
            }
            .withBlockquoteMarking { _, line, lineOrigin, usedRect in
                guard let blockquote = blockquoteContext(in: line) else { return }
                let boundingBox = usedRect.offsetBy(dx: lineOrigin.x - usedRect.minX, dy: lineOrigin.y - usedRect.maxY)
                blockquote.accumulate(boundingBox)
            }
            .withBlockquoteDrawing { context, line, lineOrigin, usedRect in
                guard let blockquote = blockquoteContext(in: line) else { return }
                let boundingBox = usedRect.offsetBy(dx: lineOrigin.x - usedRect.minX, dy: lineOrigin.y - usedRect.maxY)
                blockquote.accumulate(boundingBox)
                guard let resolvedBounds = blockquote.consumeBounds(), resolvedBounds.height > 0 else { return }
                let anchorX = resolvedBounds.minX - blockquote.headIndent + blockquote.inset
                let fallbackX = resolvedBounds.minX - blockquote.lineWidth - blockquote.inset
                let lineX = min(anchorX, fallbackX)
                let top = resolvedBounds.minY - blockquote.verticalInset
                let bottom = resolvedBounds.maxY + blockquote.verticalInset
                let height = max(0, bottom - top)
                guard height > 0 else { return }
                let lineRect = CGRect(
                    x: lineX,
                    y: top,
                    width: blockquote.lineWidth,
                    height: height
                )
                context.setFillColor(blockquote.fillColor.cgColor)
                let cornerRadius = blockquote.lineWidth / 2
                let roundedPath = CGPath(roundedRect: lineRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.addPath(roundedPath)
                context.fillPath()
            }
            .build()
    }
}
