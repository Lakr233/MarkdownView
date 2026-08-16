//
//  TextBuilder+Do.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import CoreText
import Foundation
import Litext

/// A symbol rendered at the size the marker column draws it at.
///
/// A symbol image is vector backed and hands back no `cgImage` to mask with until
/// something rasterizes it, so it is rendered here — at the fitted size, so the
/// bitmap the marker is masked from was never scaled after the fact.
private func builtinSystemImage(_ name: String) -> PlatformImage {
    #if canImport(UIKit)
        guard let image = UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(scale: .small)
        ) else { return .init() }
        let template = image.withTintColor(.label, renderingMode: .alwaysTemplate)
    #elseif canImport(AppKit)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return .init()
        }
        let template = image.withSymbolConfiguration(.init(scale: .small)) ?? image
    #endif
    return template.resized(to: ListMarkerLayout.fittedSize(for: template.size))
}

@MainActor private let kCheckedBoxImage = builtinSystemImage("checkmark.square.fill")
@MainActor private let kUncheckedBoxImage = builtinSystemImage("square")

@MainActor private var kNumberCircleImageCache: [Int: PlatformImage] = [:]

@MainActor private func kNumberCircleImage(_ number: Int) -> PlatformImage {
    if let cached = kNumberCircleImageCache[number] { return cached }
    let image = builtinSystemImage("\(number).circle.fill")
    kNumberCircleImageCache[number] = image
    return image
}

extension TextBuilder {
    @inline(__always)
    static func lineBoundingBox(_ line: CTLine, lineOrigin: CGPoint) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        return .init(x: lineOrigin.x, y: lineOrigin.y - descent, width: width, height: ascent + descent)
    }

    static func build(view: MarkdownTextView, viewProvider: ReusableViewProvider) -> BuildResult {
        let context: MarkdownContent = view.content
        let theme: MarkdownTheme = view.theme

        /// Color and font a drawn marker takes from the line it belongs to.
        ///
        /// The marker's own run leads the line, so its attributes are the ones a
        /// marker has to match: the color the theme gave that item, and the font
        /// whose cap height places the marker column.
        func markerStyle(of line: CTLine) -> (color: PlatformColor, font: PlatformFont) {
            var color = theme.colors.body
            var font = theme.fonts.body
            if let firstRun = line.glyphRuns().first,
               let attributes = CTRunGetAttributes(firstRun) as? [NSAttributedString.Key: Any]
            {
                if let runColor = attributes[.foregroundColor] as? PlatformColor {
                    color = runColor
                }
                if let runFont = attributes[.font] as? PlatformFont {
                    font = runFont
                }
            }
            return (color, font)
        }

        /// Draws a template symbol inside the marker column, scaled to fit it.
        func drawSymbol(_ image: PlatformImage, in column: CGRect, color: PlatformColor, context: CGContext) {
            #if canImport(UIKit)
                guard let cgImage = image.cgImage else { return }
            #elseif canImport(AppKit)
                guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            #endif
            let targetRect = ListMarkerLayout.fit(imageSize: image.size, in: column)
            context.clip(to: targetRect, mask: cgImage)
            context.setFillColor(color.cgColor)
            context.fill(targetRect)
        }

        #if canImport(UIKit)
            let expandedCodeBlocks = view.expandedCodeBlocks
        #else
            let expandedCodeBlocks: Set<Int> = []
        #endif

        return TextBuilder(nodes: context.blocks, context: context, viewProvider: viewProvider)
            .withTheme(theme)
            .withExpandedCodeBlocks(expandedCodeBlocks)
            .withFragmentCache(view.blockFragmentCache)
            .withInlineTextDecoration { [weak view] text in
                guard let view else { return text }
                return view.decorate(inlineText: text, theme: theme)
            }
            .withBulletDrawing { context, line, lineOrigin, depth in
                let style = markerStyle(of: line)
                let column = ListMarkerLayout.column(lineOrigin: lineOrigin, font: style.font)
                context.setStrokeColor(style.color.cgColor)
                context.setFillColor(style.color.cgColor)
                let radius: CGFloat = 3
                let rect = CGRect(
                    x: column.midX - radius,
                    y: column.midY - radius,
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
            .withNumberedDrawing { context, line, lineOrigin, num in
                let style = markerStyle(of: line)
                let column = ListMarkerLayout.column(lineOrigin: lineOrigin, font: style.font)
                context.saveGState()
                defer { context.restoreGState() }
                if (0 ... 50).contains(num) {
                    drawSymbol(kNumberCircleImage(num), in: column, color: style.color, context: context)
                    return
                }
                // Past the symbols the number is typeset, and a number wider than the
                // column has to grow away from the text rather than into it, so this one
                // hangs from the column's trailing edge instead of sharing its center.
                let font = PlatformFont.monospacedDigitSystemFont(
                    ofSize: theme.fonts.footnote.pointSize,
                    weight: .regular
                )
                let attributedText = NSAttributedString(string: "\(num).", attributes: [
                    .font: font,
                    .foregroundColor: style.color,
                ])
                let textLine = CTLineCreateWithAttributedString(attributedText)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                let width = CTLineGetTypographicBounds(textLine, &ascent, &descent, nil)
                context.textMatrix = .identity
                context.textPosition = .init(
                    x: column.maxX - width,
                    y: column.midY - (ascent - descent) / 2
                )
                CTLineDraw(textLine, context)
            }
            .withCheckboxDrawing { context, line, lineOrigin, isChecked in
                let style = markerStyle(of: line)
                let column = ListMarkerLayout.column(lineOrigin: lineOrigin, font: style.font)
                let image = if isChecked { kCheckedBoxImage } else { kUncheckedBoxImage }
                context.saveGState()
                defer { context.restoreGState() }
                drawSymbol(
                    image,
                    in: column,
                    color: style.color.withAlphaComponent(0.24),
                    context: context
                )
            }
            .withThematicBreakDrawing { [weak view] context, line, lineOrigin in
                guard let view else { return }
                let boundingBox = lineBoundingBox(line, lineOrigin: lineOrigin)

                context.setLineWidth(1)
                #if canImport(UIKit)
                    context.setStrokeColor(UIColor.label.withAlphaComponent(0.1).cgColor)
                #elseif canImport(AppKit)
                    context.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.1).cgColor)
                #endif
                context.move(to: .init(x: boundingBox.minX, y: boundingBox.midY))
                context.addLine(to: .init(x: boundingBox.minX + view.bounds.width, y: boundingBox.midY))
                context.strokePath()
            }
            .build()
    }
}
