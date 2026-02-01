//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext

#if canImport(UIKit)
    import UIKit

    final class CodeView: UIView {
        // MARK: - CONTENT

        var theme: MarkdownTheme = .default {
            didSet {
                languageLabel.font = theme.fonts.code
                textView.selectionBackgroundColor = theme.colors.selectionBackground
                updateLineNumberView()
            }
        }

        var language: String = "" {
            didSet {
                languageLabel.text = language.isEmpty ? "</>" : language
            }
        }

        var highlightMap: CodeHighlighter.HighlightMap = .init()

        var content: String = "" {
            didSet {
                guard oldValue != content else { return }
                textView.attributedText = highlightMap.apply(to: content, with: theme)
                lineNumberView.updateForContent(content)
                updateLineNumberView()
            }
        }

        // MARK: CONTENT -

        var previewAction: ((String?, NSAttributedString) -> Void)? {
            didSet {
                setNeedsLayout()
            }
        }

        private let callerIdentifier = UUID()
        private var currentTaskIdentifier: UUID?

        lazy var barView: UIView = .init()
        lazy var scrollView: UIScrollView = .init()
        lazy var languageLabel: UILabel = .init()
        lazy var textView: LTXLabel = .init()
        lazy var copyButton: UIButton = .init()
        lazy var previewButton: UIButton = .init()
        lazy var lineNumberView: LineNumberView = .init()

        override init(frame: CGRect) {
            super.init(frame: frame)
            configureSubviews()
            updateLineNumberView()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        static func intrinsicHeight(for content: String, theme: MarkdownTheme = .default) -> CGFloat {
            CodeViewConfiguration.intrinsicHeight(for: content, theme: theme)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            performLayout()
            updateLineNumberView()
        }

        override var intrinsicContentSize: CGSize {
            let labelSize = languageLabel.intrinsicContentSize
            let barHeight = labelSize.height + CodeViewConfiguration.barPadding * 2
            let textSize = textView.intrinsicContentSize
            let supposedHeight = Self.intrinsicHeight(for: content, theme: theme)

            let lineNumberWidth = lineNumberView.intrinsicContentSize.width

            return CGSize(
                width: max(
                    labelSize.width + CodeViewConfiguration.barPadding * 2,
                    lineNumberWidth + textSize.width + CodeViewConfiguration.codePadding * 2
                ),
                height: max(
                    barHeight + textSize.height + CodeViewConfiguration.codePadding * 2,
                    supposedHeight
                )
            )
        }

        @objc func handleCopy(_: UIButton) {
            UIPasteboard.general.string = content
            #if !os(visionOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }

        @objc func handlePreview(_: UIButton) {
            #if !os(visionOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            previewAction?(language, textView.attributedText)
        }

        func updateLineNumberView() {
            let font = theme.fonts.code
            lineNumberView.textColor = theme.colors.body.withAlphaComponent(0.5)

            let lineCount = max(content.components(separatedBy: .newlines).count, 1)
            let textViewContentHeight = textView.intrinsicContentSize.height

            lineNumberView.configure(
                lineCount: lineCount,
                contentHeight: textViewContentHeight,
                font: font,
                textColor: .secondaryLabel
            )

            lineNumberView.padding = UIEdgeInsets(
                top: CodeViewConfiguration.codePadding,
                left: CodeViewConfiguration.lineNumberPadding,
                bottom: CodeViewConfiguration.codePadding,
                right: CodeViewConfiguration.lineNumberPadding
            )
        }
    }

    extension CodeView: LTXAttributeStringRepresentable {
        func attributedStringRepresentation() -> NSAttributedString {
            textView.attributedText
        }
    }

#elseif canImport(AppKit)
    import AppKit

    final class CodeView: NSView {
        var theme: MarkdownTheme = .default {
            didSet {
                languageLabel.font = theme.fonts.code
                textView.selectionBackgroundColor = theme.colors.selectionBackground
                updateLineNumberView()
            }
        }

        var language: String = "" {
            didSet {
                languageLabel.stringValue = language.isEmpty ? "</>" : language
            }
        }

        var highlightMap: CodeHighlighter.HighlightMap = .init()

        var content: String = "" {
            didSet {
                guard oldValue != content else { return }
                textView.attributedText = highlightMap.apply(to: content, with: theme)
                lineNumberView.updateForContent(content)
                updateLineNumberView()
            }
        }

        var previewAction: ((String?, NSAttributedString) -> Void)? {
            didSet {
                needsLayout = true
            }
        }

        private let callerIdentifier = UUID()
        private var currentTaskIdentifier: UUID?

        lazy var barView: NSView = .init()
        lazy var scrollView: NSScrollView = {
            let sv = NSScrollView()
            sv.hasVerticalScroller = false
            sv.hasHorizontalScroller = false
            sv.drawsBackground = false
            return sv
        }()

        lazy var languageLabel: NSTextField = {
            let label = NSTextField(labelWithString: "")
            label.isEditable = false
            label.isBordered = false
            label.backgroundColor = .clear
            return label
        }()

        lazy var textView: LTXLabel = .init()
        lazy var copyButton: NSButton = .init(title: "", target: nil, action: nil)
        lazy var previewButton: NSButton = .init(title: "", target: nil, action: nil)
        lazy var lineNumberView: LineNumberView = .init()

        override init(frame: CGRect) {
            super.init(frame: frame)
            configureSubviews()
            updateLineNumberView()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isFlipped: Bool {
            true
        }

        static func intrinsicHeight(for content: String, theme: MarkdownTheme = .default) -> CGFloat {
            CodeViewConfiguration.intrinsicHeight(for: content, theme: theme)
        }

        override func layout() {
            super.layout()
            performLayout()
            updateLineNumberView()
        }

        override var intrinsicContentSize: CGSize {
            let labelSize = languageLabel.intrinsicContentSize
            let barHeight = labelSize.height + CodeViewConfiguration.barPadding * 2
            let textSize = textView.intrinsicContentSize
            let supposedHeight = Self.intrinsicHeight(for: content, theme: theme)

            let lineNumberWidth = lineNumberView.intrinsicContentSize.width

            return CGSize(
                width: max(
                    labelSize.width + CodeViewConfiguration.barPadding * 2,
                    lineNumberWidth + textSize.width + CodeViewConfiguration.codePadding * 2
                ),
                height: max(
                    barHeight + textSize.height + CodeViewConfiguration.codePadding * 2,
                    supposedHeight
                )
            )
        }

        @objc func handleCopy(_: Any?) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
        }

        @objc func handlePreview(_: Any?) {
            previewAction?(language, textView.attributedText)
        }

        func updateLineNumberView() {
            let font = theme.fonts.code
            lineNumberView.textColor = theme.colors.body.withAlphaComponent(0.5)

            let lineCount = max(content.components(separatedBy: .newlines).count, 1)
            let textViewContentHeight = textView.intrinsicContentSize.height

            lineNumberView.configure(
                lineCount: lineCount,
                contentHeight: textViewContentHeight,
                font: font,
                textColor: .secondaryLabelColor
            )

            lineNumberView.padding = NSEdgeInsets(
                top: CodeViewConfiguration.codePadding,
                left: CodeViewConfiguration.lineNumberPadding,
                bottom: CodeViewConfiguration.codePadding,
                right: CodeViewConfiguration.lineNumberPadding
            )
        }
    }

    extension CodeView: LTXAttributeStringRepresentable {
        func attributedStringRepresentation() -> NSAttributedString {
            textView.attributedText
        }
    }
#endif
