//
//  Created by Lakr233 on 2025/1/22.
//  Copyright (c) 2025 MarkdownView. All rights reserved.
//

import Litext

#if canImport(UIKit)
    import UIKit

    final class LineNumberView: UIView {
        var lineCount: Int = 1 {
            didSet {
                setNeedsDisplay()
                invalidateIntrinsicContentSize()
            }
        }

        var font: UIFont = .monospacedSystemFont(ofSize: 12, weight: .regular) {
            didSet {
                setNeedsDisplay()
                invalidateIntrinsicContentSize()
            }
        }

        var textColor: UIColor = .secondaryLabel {
            didSet { setNeedsDisplay() }
        }

        var padding: UIEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8) {
            didSet {
                setNeedsDisplay()
                invalidateIntrinsicContentSize()
            }
        }

        var contentHeight: CGFloat = 0 {
            didSet {
                setNeedsDisplay()
                invalidateIntrinsicContentSize()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setupView() {
            backgroundColor = .clear
            isOpaque = false
            contentMode = .redraw
        }

        override var intrinsicContentSize: CGSize {
            let maxLineNumber = max(lineCount, 1)
            let numberString = "\(maxLineNumber)"
            let textSize = numberString.size(withAttributes: [.font: font])

            return CGSize(
                width: textSize.width + padding.left + padding.right,
                height: max(contentHeight + padding.top + padding.bottom, textSize.height + padding.top + padding.bottom)
            )
        }

        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.clear(rect)

            guard lineCount > 0, contentHeight > 0 else { return }

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
            ]

            let availableHeight = contentHeight
            let lineSpacing = availableHeight / CGFloat(lineCount)
            let startY = padding.top

            for lineNumber in 1 ... lineCount {
                let numberString = "\(lineNumber)"
                let textSize = numberString.size(withAttributes: textAttributes)

                let x = bounds.width - padding.right - textSize.width
                let y = startY + CGFloat(lineNumber - 1) * lineSpacing + (lineSpacing - textSize.height) / 2

                let textRect = CGRect(
                    x: x,
                    y: y,
                    width: textSize.width,
                    height: textSize.height
                )

                numberString.draw(in: textRect, withAttributes: textAttributes)
            }
        }

        func configure(lineCount: Int, contentHeight: CGFloat, font: UIFont, textColor: UIColor) {
            self.lineCount = lineCount
            self.contentHeight = contentHeight
            self.font = font
            self.textColor = textColor
        }

        func updateForContent(_ content: String) {
            let lines = content.components(separatedBy: .newlines)
            lineCount = max(lines.count, 1)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    final class LineNumberView: NSView {
        var lineCount: Int = 1 {
            didSet {
                needsDisplay = true
                invalidateIntrinsicContentSize()
            }
        }

        var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular) {
            didSet {
                needsDisplay = true
                invalidateIntrinsicContentSize()
            }
        }

        var textColor: NSColor = .secondaryLabelColor {
            didSet { needsDisplay = true }
        }

        var padding: NSEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8) {
            didSet {
                needsDisplay = true
                invalidateIntrinsicContentSize()
            }
        }

        var contentHeight: CGFloat = 0 {
            didSet {
                needsDisplay = true
                invalidateIntrinsicContentSize()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isFlipped: Bool {
            true
        }

        private func setupView() {
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        override var intrinsicContentSize: CGSize {
            let maxLineNumber = max(lineCount, 1)
            let numberString = "\(maxLineNumber)"
            let textSize = numberString.size(withAttributes: [.font: font])

            return CGSize(
                width: textSize.width + padding.left + padding.right,
                height: max(contentHeight + padding.top + padding.bottom, textSize.height + padding.top + padding.bottom)
            )
        }

        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.clear(dirtyRect)

            guard lineCount > 0, contentHeight > 0 else { return }

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
            ]

            let availableHeight = contentHeight
            let lineSpacing = availableHeight / CGFloat(lineCount)
            let startY = padding.top

            for lineNumber in 1 ... lineCount {
                let numberString = "\(lineNumber)"
                let textSize = numberString.size(withAttributes: textAttributes)

                let x = bounds.width - padding.right - textSize.width
                let y = startY + CGFloat(lineNumber - 1) * lineSpacing + (lineSpacing - textSize.height) / 2

                let textRect = CGRect(
                    x: x,
                    y: y,
                    width: textSize.width,
                    height: textSize.height
                )

                numberString.draw(in: textRect, withAttributes: textAttributes)
            }
        }

        func configure(lineCount: Int, contentHeight: CGFloat, font: NSFont, textColor: NSColor) {
            self.lineCount = lineCount
            self.contentHeight = contentHeight
            self.font = font
            self.textColor = textColor
        }

        func updateForContent(_ content: String) {
            let lines = content.components(separatedBy: .newlines)
            lineCount = max(lines.count, 1)
        }
    }
#endif
