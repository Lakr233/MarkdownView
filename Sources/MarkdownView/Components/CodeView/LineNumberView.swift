//
//  Created by Lakr233 on 2025/1/22.
//  Copyright (c) 2025 MarkdownView. All rights reserved.
//

import Litext

final class LineNumberView: PlatformView {
    #if canImport(UIKit)
        typealias EdgeInsets = UIEdgeInsets
        private static var defaultTextColor: PlatformColor {
            .secondaryLabel
        }
    #elseif canImport(AppKit)
        typealias EdgeInsets = NSEdgeInsets
        private static var defaultTextColor: PlatformColor {
            .secondaryLabelColor
        }
    #endif

    var lineCount: Int = 1 {
        didSet {
            guard oldValue != lineCount else { return }
            markNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }

    var font: PlatformFont = .monospacedSystemFont(ofSize: 12, weight: .regular) {
        didSet {
            guard oldValue != font else { return }
            markNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }

    var textColor: PlatformColor = defaultTextColor {
        didSet {
            guard oldValue != textColor else { return }
            markNeedsDisplay()
        }
    }

    var padding: EdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8) {
        didSet {
            #if canImport(UIKit)
                guard oldValue != padding else { return }
            #elseif canImport(AppKit)
                guard !NSEdgeInsetsEqual(oldValue, padding) else { return }
            #endif
            markNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }

    var contentHeight: CGFloat = 0 {
        didSet {
            guard oldValue != contentHeight else { return }
            markNeedsDisplay()
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

    #if canImport(UIKit)
        private func setupView() {
            backgroundColor = .clear
            isOpaque = false
            contentMode = .redraw
        }

        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.clear(rect)
            drawLineNumbers(in: rect)
        }
    #elseif canImport(AppKit)
        override var isFlipped: Bool {
            true
        }

        private func setupView() {
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.clear(dirtyRect)
            drawLineNumbers(in: dirtyRect)
        }
    #endif

    override var intrinsicContentSize: CGSize {
        let maxLineNumber = max(lineCount, 1)
        let numberString = "\(maxLineNumber)"
        let textSize = numberString.size(withAttributes: [.font: font])

        return CGSize(
            width: textSize.width + padding.left + padding.right,
            height: max(contentHeight + padding.top + padding.bottom, textSize.height + padding.top + padding.bottom)
        )
    }

    /// Draws the numbers of the lines that cross `rect`, into the context
    /// the platform's `draw` has already cleared.
    private func drawLineNumbers(in rect: CGRect) {
        guard lineCount > 0, contentHeight > 0 else { return }

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]

        let availableHeight = contentHeight
        let lineSpacing = availableHeight / CGFloat(lineCount)
        let startY = padding.top

        guard lineSpacing > 0 else { return }

        let firstLine = max(1, Int(floor((rect.minY - padding.top) / lineSpacing)))
        let lastLine = min(lineCount, Int(ceil((rect.maxY - padding.top) / lineSpacing)) + 1)
        guard firstLine <= lastLine else { return }

        let textHeight = "0".size(withAttributes: textAttributes).height
        var digitCount = 0
        var textWidth: CGFloat = 0

        for lineNumber in firstLine ... lastLine {
            let numberString = "\(lineNumber)"
            if numberString.count != digitCount {
                digitCount = numberString.count
                textWidth = numberString.size(withAttributes: textAttributes).width
            }

            let x = bounds.width - padding.right - textWidth
            let y = startY + CGFloat(lineNumber - 1) * lineSpacing + (lineSpacing - textHeight) / 2

            let textRect = CGRect(
                x: x,
                y: y,
                width: textWidth,
                height: textHeight
            )

            numberString.draw(in: textRect, withAttributes: textAttributes)
        }
    }

    func configure(lineCount: Int, contentHeight: CGFloat, font: PlatformFont, textColor: PlatformColor) {
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
