//
//  WatchTextBuilder.swift
//  WatchMarkdownView
//

import CoreGraphics
import CoreText
import Foundation
import Litext
import MarkdownParser

@MainActor
struct WatchTextBuilder {
    let blocks: [MarkdownBlockNode]
    let theme: WatchMarkdownTheme
    let maxWidth: CGFloat
    let scale: CGFloat

    func build() -> NSAttributedString {
        let result = NSMutableAttributedString()
        appendBlocks(blocks, to: result, context: .init(), theme: theme)
        trimTrailingNewlines(from: result)

        guard result.length > 0 else {
            return NSAttributedString(
                string: " ",
                attributes: baseAttributes(font: theme.bodyFont, theme: theme)
            )
        }
        return result
    }
}

// MARK: - Block Rendering

private extension WatchTextBuilder {
    struct RenderContext {
        var leadingInset: CGFloat = 0
    }

    enum ListMarker {
        case bullet(depth: Int)
        case numbered(Int)
        case task(isCompleted: Bool)
    }

    typealias LineAction = (CGContext, CTLine, CGPoint) -> Void

    func appendBlocks(
        _ blocks: [MarkdownBlockNode],
        to result: NSMutableAttributedString,
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) {
        for block in blocks {
            appendBlock(block, to: result, context: context, theme: theme)
        }
    }

    func appendBlock(
        _ block: MarkdownBlockNode,
        to result: NSMutableAttributedString,
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) {
        switch block {
        case let .paragraph(content):
            result.append(
                renderTextBlock(
                    content.render(theme: theme, baseFont: theme.bodyFont),
                    font: theme.bodyFont,
                    paragraphSpacing: theme.blockSpacing,
                    context: context,
                    theme: theme
                )
            )

        case let .heading(level, content):
            result.append(
                renderTextBlock(
                    content.render(theme: theme, baseFont: headingFont(level: level, theme: theme)),
                    font: headingFont(level: level, theme: theme),
                    paragraphSpacing: theme.blockSpacing * 1.5,
                    context: context,
                    theme: theme
                )
            )

        case let .codeBlock(_, code):
            result.append(renderCodeBlock(code, context: context, theme: theme))

        case let .blockquote(children):
            result.append(renderBlockquote(children, context: context, theme: theme))

        case let .bulletedList(isTight, items):
            appendList(
                flattenList(.bulleted(items), depth: 0),
                to: result,
                isTight: isTight,
                context: context,
                theme: theme
            )

        case let .numberedList(isTight, start, items):
            appendList(
                flattenList(.numbered(start, items), depth: 0),
                to: result,
                isTight: isTight,
                context: context,
                theme: theme
            )

        case let .taskList(isTight, items):
            appendList(
                flattenList(.task(items), depth: 0),
                to: result,
                isTight: isTight,
                context: context,
                theme: theme
            )

        case let .table(columnAlignments, rows):
            result.append(
                renderTable(
                    rows: rows,
                    columnAlignments: columnAlignments,
                    context: context,
                    theme: theme
                )
            )

        case .thematicBreak:
            result.append(renderThematicBreak(context: context, theme: theme))
        }
    }

    func renderTextBlock(
        _ content: NSAttributedString,
        font: CTFont,
        paragraphSpacing: CGFloat,
        marker: ListMarker? = nil,
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let prefixLength = result.length

        if let marker {
            result.append(markerPrefix(marker: marker, theme: theme))
        }

        let bodyStart = result.length
        if content.length == 0 {
            result.append(
                NSAttributedString(
                    string: " ",
                    attributes: baseAttributes(font: font, theme: theme)
                )
            )
        } else {
            result.append(content)
        }

        let bodyRange = NSRange(location: bodyStart, length: result.length - bodyStart)
        if let action = makeCombinedAction(
            nil,
            nil
        ) {
            result.addAttribute(.ltxLineDrawingCallback, value: action, range: bodyRange)
        }

        if let marker {
            let markerRange = NSRange(location: prefixLength, length: 1)
            result.addAttribute(
                .ltxLineDrawingCallback,
                value: LTXLineDrawingAction { drawContext, line, lineOrigin in
                    drawMarker(
                        marker,
                        font: font,
                        theme: theme,
                        indent: context.leadingInset + markerIndent(for: marker, font: font, theme: theme),
                        in: drawContext,
                        line: line,
                        lineOrigin: lineOrigin
                    )
                },
                range: markerRange
            )
        }

        applyParagraphStyle(
            to: result,
            baseFont: font,
            leadingInset: context.leadingInset,
            marker: marker,
            lineSpacing: 4,
            paragraphSpacing: paragraphSpacing,
            extraInsets: .zero,
            theme: theme
        )

        if !result.string.hasSuffix("\n") {
            result.append(NSAttributedString(string: "\n"))
        }
        return result
    }

    func renderCodeBlock(
        _ code: String,
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) -> NSAttributedString {
        let rendered = WatchCodeBlockRenderer.render(
            code: code,
            theme: theme,
            maxWidth: max(1, maxWidth - context.leadingInset),
            scale: scale
        )

        guard let image = rendered.image, rendered.size != .zero else {
            return NSAttributedString()
        }

        let attachment = LTXAttachment.hold(
            attrString: NSAttributedString(
                string: code.deletingTrailingCharacters(in: .whitespacesAndNewlines) + "\n",
                attributes: codeAttributes(theme: theme)
            )
        )
        attachment.size = rendered.size

        let result = NSMutableAttributedString(
            string: LTXReplacementText,
            attributes: [
                .font: theme.codeFont,
                .ltxAttachment: attachment,
            ]
        )

        if let action = makeCombinedAction(
            nil,
            imageAction(image: image, size: rendered.size, context: context)
        ) {
            result.addAttribute(
                .ltxLineDrawingCallback,
                value: action,
                range: NSRange(location: 0, length: result.length)
            )
        }

        let paragraph = makeParagraphStyle(
            firstLineHeadIndent: context.leadingInset,
            headIndent: context.leadingInset,
            minimumLineHeight: rendered.size.height,
            maximumLineHeight: rendered.size.height,
            paragraphSpacing: theme.blockSpacing
        )
        result.addAttribute(
            kCTParagraphStyleAttributeName as NSAttributedString.Key,
            value: paragraph,
            range: NSRange(location: 0, length: result.length)
        )
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    func renderBlockquote(
        _ children: [MarkdownBlockNode],
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) -> NSAttributedString {
        var quoteTheme = theme
        quoteTheme.textColor = theme.blockquoteTextColor

        var quoteContext = context
        quoteContext.leadingInset += theme.blockquoteBarWidth + 8

        let result = NSMutableAttributedString()
        appendBlocks(children, to: result, context: quoteContext, theme: quoteTheme)
        trimTrailingNewlines(from: result)

        guard result.length > 0 else {
            return NSAttributedString()
        }

        var quoteTopY: CGFloat?
        var startMarkerAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.bodyFont,
        ]
        var endMarkerAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.bodyFont,
        ]

        if let paragraphStyle = result.attribute(
            kCTParagraphStyleAttributeName as NSAttributedString.Key,
            at: 0,
            effectiveRange: nil
        ) {
            startMarkerAttributes[kCTParagraphStyleAttributeName as NSAttributedString.Key] = paragraphStyle
        }
        if let paragraphStyle = result.attribute(
            kCTParagraphStyleAttributeName as NSAttributedString.Key,
            at: max(0, result.length - 1),
            effectiveRange: nil
        ) {
            endMarkerAttributes[kCTParagraphStyleAttributeName as NSAttributedString.Key] = paragraphStyle
        }

        let startMarker = NSMutableAttributedString(
            string: LTXReplacementText,
            attributes: startMarkerAttributes
        )
        startMarker.addAttribute(
            .ltxLineDrawingCallback,
            value: LTXLineDrawingAction { _, line, lineOrigin in
                quoteTopY = lineBounds(line: line, origin: lineOrigin).maxY
            },
            range: NSRange(location: 0, length: 1)
        )

        let endMarker = NSMutableAttributedString(
            string: LTXReplacementText,
            attributes: endMarkerAttributes
        )
        endMarker.addAttribute(
            .ltxLineDrawingCallback,
            value: LTXLineDrawingAction { drawContext, line, lineOrigin in
                guard let quoteTopY else { return }
                let lineRect = lineBounds(line: line, origin: lineOrigin)
                let rect = CGRect(
                    x: context.leadingInset,
                    y: lineRect.minY,
                    width: theme.blockquoteBarWidth,
                    height: quoteTopY - lineRect.minY
                )
                let path = CGPath(
                    roundedRect: rect,
                    cornerWidth: theme.blockquoteBarWidth / 2,
                    cornerHeight: theme.blockquoteBarWidth / 2,
                    transform: nil
                )
                drawContext.addPath(path)
                drawContext.setFillColor(theme.blockquoteBorderColor)
                drawContext.fillPath()
            },
            range: NSRange(location: 0, length: 1)
        )

        result.insert(startMarker, at: 0)
        result.append(endMarker)
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    func renderThematicBreak(
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) -> NSAttributedString {
        let attachment = LTXAttachment.hold(attrString: NSAttributedString(string: "\n"))
        attachment.size = CGSize(width: 1, height: max(8, theme.bodySize))

        let result = NSMutableAttributedString(
            string: LTXReplacementText,
            attributes: [
                .font: theme.bodyFont,
                .ltxAttachment: attachment,
            ]
        )

        if let action = makeCombinedAction(
            nil,
            separatorAction(context: context, theme: theme)
        ) {
            result.addAttribute(.ltxLineDrawingCallback, value: action, range: NSRange(location: 0, length: result.length))
        }

        let lineHeight = max(theme.bodySize, attachment.size.height)
        let paragraph = makeParagraphStyle(
            firstLineHeadIndent: context.leadingInset,
            headIndent: context.leadingInset,
            minimumLineHeight: lineHeight,
            maximumLineHeight: lineHeight,
            paragraphSpacing: theme.blockSpacing
        )
        result.addAttribute(
            kCTParagraphStyleAttributeName as NSAttributedString.Key,
            value: paragraph,
            range: NSRange(location: 0, length: result.length)
        )
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    func renderTable(
        rows: [RawTableRow],
        columnAlignments: [RawTableColumnAlignment],
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) -> NSAttributedString {
        let rendered = WatchTableRenderer.render(
            rows: rows,
            columnAlignments: columnAlignments,
            theme: theme,
            maxWidth: max(1, maxWidth - context.leadingInset),
            scale: scale
        )

        guard let image = rendered.image, rendered.size != .zero else {
            return NSAttributedString()
        }

        let attachment = LTXAttachment.hold(attrString: tableRepresentation(rows: rows))
        attachment.size = rendered.size

        let result = NSMutableAttributedString(
            string: LTXReplacementText,
            attributes: [
                .font: theme.bodyFont,
                .ltxAttachment: attachment,
            ]
        )

        let action = makeCombinedAction(
            nil,
            imageAction(image: image, size: rendered.size, context: context)
        )
        if let action {
            result.addAttribute(.ltxLineDrawingCallback, value: action, range: NSRange(location: 0, length: result.length))
        }

        let paragraph = makeParagraphStyle(
            firstLineHeadIndent: context.leadingInset,
            headIndent: context.leadingInset,
            minimumLineHeight: rendered.size.height,
            maximumLineHeight: rendered.size.height,
            paragraphSpacing: theme.blockSpacing
        )
        result.addAttribute(
            kCTParagraphStyleAttributeName as NSAttributedString.Key,
            value: paragraph,
            range: NSRange(location: 0, length: result.length)
        )
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    func appendList(
        _ items: [FlatListItem],
        to result: NSMutableAttributedString,
        isTight: Bool,
        context: RenderContext,
        theme: WatchMarkdownTheme
    ) {
        let paragraphSpacing = isTight ? 2 : theme.blockSpacing
        for item in items {
            var itemContext = context
            itemContext.leadingInset += listIndent(depth: item.depth, theme: theme)

            let marker: ListMarker = if item.isTask {
                .task(isCompleted: item.isDone)
            } else if item.ordered {
                .numbered(item.index)
            } else {
                .bullet(depth: item.depth)
            }

            result.append(
                renderTextBlock(
                    item.paragraph.render(theme: theme, baseFont: theme.bodyFont),
                    font: theme.bodyFont,
                    paragraphSpacing: paragraphSpacing,
                    marker: marker,
                    context: itemContext,
                    theme: theme
                )
            )
        }
    }
}

// MARK: - Drawing

private extension WatchTextBuilder {
    func makeCombinedAction(_ first: LineAction?, _ second: LineAction?) -> LTXLineDrawingAction? {
        guard first != nil || second != nil else { return nil }
        return LTXLineDrawingAction { context, line, lineOrigin in
            first?(context, line, lineOrigin)
            second?(context, line, lineOrigin)
        }
    }

    func quoteAction(context _: RenderContext, theme _: WatchMarkdownTheme) -> LineAction? {
        nil
    }

    func separatorAction(context: RenderContext, theme: WatchMarkdownTheme) -> LineAction {
        { drawContext, line, lineOrigin in
            let lineRect = lineBounds(line: line, origin: lineOrigin)
            let centerY = lineRect.midY
            drawContext.setStrokeColor(theme.separatorColor)
            drawContext.setLineWidth(1)
            drawContext.move(to: CGPoint(x: context.leadingInset, y: centerY))
            drawContext.addLine(to: CGPoint(x: maxWidth, y: centerY))
            drawContext.strokePath()
        }
    }

    func imageAction(
        image: CGImage,
        size: CGSize,
        context: RenderContext
    ) -> LineAction {
        { drawContext, line, lineOrigin in
            let lineRect = lineBounds(line: line, origin: lineOrigin)
            let rect = CGRect(
                x: context.leadingInset,
                y: lineRect.minY,
                width: size.width,
                height: size.height
            )
            drawContext.draw(image, in: rect)
        }
    }

    func drawMarker(
        _ marker: ListMarker,
        font: CTFont,
        theme: WatchMarkdownTheme,
        indent: CGFloat,
        in context: CGContext,
        line: CTLine,
        lineOrigin: CGPoint
    ) {
        let lineRect = lineBounds(line: line, origin: lineOrigin)
        let gap: CGFloat = 6

        switch marker {
        case let .bullet(depth):
            let diameter: CGFloat = depth == 0 ? 5 : 4
            let rect = CGRect(
                x: indent - gap - diameter,
                y: lineRect.midY - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.setFillColor(theme.textColor)
            context.fillEllipse(in: rect)

        case let .numbered(index):
            let markerText = NSAttributedString(
                string: "\(index).",
                attributes: baseAttributes(font: font, theme: theme)
            )
            let ctLine = CTLineCreateWithAttributedString(markerText as CFAttributedString)
            let markerWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            context.textPosition = CGPoint(x: indent - gap - markerWidth, y: lineOrigin.y)
            CTLineDraw(ctLine, context)

        case let .task(isCompleted):
            let boxSize: CGFloat = 10
            let rect = CGRect(
                x: indent - gap - boxSize,
                y: lineRect.midY - boxSize / 2,
                width: boxSize,
                height: boxSize
            )

            context.setLineWidth(1.25)
            context.setStrokeColor(isCompleted ? theme.accentColor : theme.textColor)
            context.stroke(rect)

            guard isCompleted else { return }

            context.setStrokeColor(theme.accentColor)
            context.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.minX + 4.5, y: rect.minY + 2))
            context.addLine(to: CGPoint(x: rect.maxX - 1.5, y: rect.maxY - 2))
            context.strokePath()
        }
    }
}

// MARK: - Layout

private extension WatchTextBuilder {
    func applyParagraphStyle(
        to string: NSMutableAttributedString,
        baseFont: CTFont,
        leadingInset: CGFloat,
        marker: ListMarker?,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat,
        extraInsets: CGSize,
        theme: WatchMarkdownTheme
    ) {
        let markerInset = marker.map { markerIndent(for: $0, font: baseFont, theme: theme) } ?? 0
        let paragraph = makeParagraphStyle(
            firstLineHeadIndent: leadingInset + markerInset + extraInsets.width,
            headIndent: leadingInset + markerInset + extraInsets.width,
            lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing
        )
        string.addAttribute(
            kCTParagraphStyleAttributeName as NSAttributedString.Key,
            value: paragraph,
            range: NSRange(location: 0, length: string.length)
        )
    }

    func makeParagraphStyle(
        firstLineHeadIndent: CGFloat,
        headIndent: CGFloat,
        lineSpacing: CGFloat = 0,
        minimumLineHeight: CGFloat = 0,
        maximumLineHeight: CGFloat = 0,
        paragraphSpacing: CGFloat = 0
    ) -> CTParagraphStyle {
        var firstLineHeadIndent = firstLineHeadIndent
        var headIndent = headIndent
        var lineSpacing = lineSpacing
        var minimumLineHeight = minimumLineHeight
        var maximumLineHeight = maximumLineHeight
        var paragraphSpacing = paragraphSpacing

        return withUnsafePointer(to: &firstLineHeadIndent) { firstLinePointer in
            withUnsafePointer(to: &headIndent) { headPointer in
                withUnsafePointer(to: &lineSpacing) { lineSpacingPointer in
                    withUnsafePointer(to: &minimumLineHeight) { minimumLineHeightPointer in
                        withUnsafePointer(to: &maximumLineHeight) { maximumLineHeightPointer in
                            withUnsafePointer(to: &paragraphSpacing) { paragraphSpacingPointer in
                                var settings = [
                                    CTParagraphStyleSetting(
                                        spec: .firstLineHeadIndent,
                                        valueSize: MemoryLayout<CGFloat>.size,
                                        value: firstLinePointer
                                    ),
                                    CTParagraphStyleSetting(
                                        spec: .headIndent,
                                        valueSize: MemoryLayout<CGFloat>.size,
                                        value: headPointer
                                    ),
                                    CTParagraphStyleSetting(
                                        spec: .lineSpacingAdjustment,
                                        valueSize: MemoryLayout<CGFloat>.size,
                                        value: lineSpacingPointer
                                    ),
                                    CTParagraphStyleSetting(
                                        spec: .minimumLineHeight,
                                        valueSize: MemoryLayout<CGFloat>.size,
                                        value: minimumLineHeightPointer
                                    ),
                                    CTParagraphStyleSetting(
                                        spec: .maximumLineHeight,
                                        valueSize: MemoryLayout<CGFloat>.size,
                                        value: maximumLineHeightPointer
                                    ),
                                    CTParagraphStyleSetting(
                                        spec: .paragraphSpacing,
                                        valueSize: MemoryLayout<CGFloat>.size,
                                        value: paragraphSpacingPointer
                                    ),
                                ]
                                return CTParagraphStyleCreate(&settings, settings.count)
                            }
                        }
                    }
                }
            }
        }
    }

    func headingFont(level: Int, theme: WatchMarkdownTheme) -> CTFont {
        switch level {
        case 1: theme.h1Font
        case 2: theme.h2Font
        case 3: theme.h3Font
        default: theme.h4Font
        }
    }

    func markerIndent(for marker: ListMarker, font: CTFont, theme: WatchMarkdownTheme) -> CGFloat {
        let gap: CGFloat = 6
        switch marker {
        case .bullet:
            return 12 + gap
        case let .numbered(index):
            let string = NSAttributedString(
                string: "\(index).",
                attributes: baseAttributes(font: font, theme: theme)
            )
            let ctLine = CTLineCreateWithAttributedString(string as CFAttributedString)
            return CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil)) + gap
        case .task:
            return 10 + gap
        }
    }

    func listIndent(depth: Int, theme: WatchMarkdownTheme) -> CGFloat {
        CGFloat(depth) * (theme.bodySize + theme.listIndent)
    }

    func lineBounds(line: CTLine, origin: CGPoint) -> CGRect {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        return CGRect(
            x: origin.x,
            y: origin.y - descent,
            width: width,
            height: ascent + descent + leading
        )
    }

    func trimTrailingNewlines(from string: NSMutableAttributedString) {
        while string.string.hasSuffix("\n") {
            string.deleteCharacters(in: NSRange(location: string.length - 1, length: 1))
        }
    }

    func markerPrefix(marker _: ListMarker, theme: WatchMarkdownTheme) -> NSAttributedString {
        NSAttributedString(
            string: LTXReplacementText,
            attributes: baseAttributes(font: theme.bodyFont, theme: theme)
        )
    }

    func tableRepresentation(rows: [RawTableRow]) -> NSAttributedString {
        let plainText = rows
            .map { row in
                row.cells.map { $0.content.map(\.plainText).joined() }.joined(separator: "\t")
            }
            .joined(separator: "\n")
        return NSAttributedString(string: plainText + "\n")
    }

    func flattenList(_ list: FlatList, depth: Int) -> [FlatListItem] {
        var result: [FlatListItem] = []
        var nextIndex = 0
        var ordered = false

        struct MappedItem {
            let isDone: Bool?
            let nodes: [MarkdownBlockNode]
        }

        func handle(_ items: [MappedItem], startAt: Int = 0, orderedValue: Bool) {
            nextIndex = startAt
            ordered = orderedValue

            for item in items {
                for child in item.nodes {
                    switch child {
                    case let .paragraph(contents):
                        result.append(
                            FlatListItem(
                                depth: depth,
                                ordered: ordered,
                                index: nextIndex,
                                isTask: item.isDone != nil,
                                isDone: item.isDone ?? false,
                                paragraph: contents
                            )
                        )
                        nextIndex += 1
                    case let .bulletedList(_, children):
                        result.append(contentsOf: flattenList(.bulleted(children), depth: depth + 1))
                    case let .numberedList(_, start, children):
                        result.append(contentsOf: flattenList(.numbered(start, children), depth: depth + 1))
                    case let .taskList(_, children):
                        result.append(contentsOf: flattenList(.task(children), depth: depth + 1))
                    default:
                        assertionFailure("Unsupported list child: \(child)")
                    }
                }
            }
        }

        switch list {
        case let .bulleted(items):
            handle(items.map { MappedItem(isDone: nil, nodes: $0.children) }, orderedValue: false)
        case let .numbered(start, items):
            handle(items.map { MappedItem(isDone: nil, nodes: $0.children) }, startAt: start, orderedValue: true)
        case let .task(items):
            handle(items.map { MappedItem(isDone: $0.isCompleted, nodes: $0.children) }, orderedValue: false)
        }

        return result
    }
}

// MARK: - List Types

private extension WatchTextBuilder {
    enum FlatList {
        case bulleted([RawListItem])
        case numbered(Int, [RawListItem])
        case task([RawTaskListItem])
    }

    struct FlatListItem {
        let depth: Int
        let ordered: Bool
        let index: Int
        let isTask: Bool
        let isDone: Bool
        let paragraph: [MarkdownInlineNode]
    }
}

// MARK: - Attributes

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

private extension String {
    func deletingTrailingCharacters(in set: CharacterSet) -> String {
        var copy = self
        while let last = copy.unicodeScalars.last, set.contains(last) {
            copy.removeLast()
        }
        return copy
    }
}

private extension MarkdownInlineNode {
    var plainText: String {
        switch self {
        case let .text(string), let .code(string), let .html(string), let .math(string, _):
            string
        case .softBreak, .lineBreak:
            "\n"
        case let .emphasis(children),
             let .strong(children),
             let .strikethrough(children),
             let .link(_, children):
            children.map(\.plainText).joined()
        case let .image(source, _):
            source
        }
    }
}
