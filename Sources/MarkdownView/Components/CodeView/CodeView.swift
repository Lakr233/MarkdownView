//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext

#if canImport(UIKit)
    import UIKit

    final class CodeView: UIView, UIScrollViewDelegate {
        // MARK: - CONTENT

        private var needsTextRebuild = false

        var theme: MarkdownTheme = .default {
            didSet {
                languageLabel.font = theme.fonts.code
                textView.selectionBackgroundColor = theme.colors.selectionBackground
                updateLineNumberView()
                if oldValue.fonts.code != theme.fonts.code || oldValue.colors.code != theme.colors.code {
                    needsTextRebuild = true
                }
            }
        }

        var language: String = "" {
            didSet {
                languageLabel.text = language.isEmpty ? "</>" : language
            }
        }

        var highlightMap: CodeHighlighter.HighlightMap = .init() {
            didSet {
                if oldValue != highlightMap {
                    needsTextRebuild = true
                }
            }
        }

        var content: String = "" {
            didSet {
                guard oldValue != content || needsTextRebuild else { return }
                needsTextRebuild = false
                cachedLineCount = max(content.components(separatedBy: .newlines).count, 1)
                if !isCollapsible { isExpanded = false }
                textView.attributedText = highlightMap.apply(to: content, with: theme)
                lineNumberView.updateForContent(content)
                updateLineNumberView()
                updateExpandButton()
            }
        }

        private static let collapsedLineLimit = 15
        /// The collapsed preview shows half a line past the limit: a cleanly
        /// cut block reads as complete, while a clipped line tells the reader
        /// there is more and the preview scrolls.
        private static let collapsedPreviewLines: CGFloat = 15.5

        private var cachedLineCount: Int = 1
        private var highlightedContent: String = ""
        var isExpanded = false

        /// The block's index in document order; the expansion state lives
        /// per index on the host view, so a rebuild always knows which
        /// block this one is.
        var codeBlockIndex: Int = 0

        var preferredHeightDidChange: (() -> Void)?

        var isCollapsible: Bool {
            CodeBlockCollapse.isEnabled && cachedLineCount > Self.collapsedLineLimit
        }

        private var displayedLineCount: CGFloat {
            isExpanded || !isCollapsible ? CGFloat(cachedLineCount) : Self.collapsedPreviewLines
        }

        /// Applies content and its highlight map together. Pass `nil` while the
        /// map for `newContent` is still being computed: the previous map is kept
        /// when the new content extends the previously highlighted content
        /// (streaming append), so the colored prefix does not flash back to
        /// plain text on every chunk.
        func setContent(_ newContent: String, highlightMap map: CodeHighlighter.HighlightMap?) {
            if let map {
                highlightedContent = newContent
                highlightMap = map
            } else if !newContent.hasPrefix(highlightedContent) {
                highlightedContent = ""
                highlightMap = .init()
            }
            content = newContent
        }

        // MARK: CONTENT -

        var previewAction: ((String?, NSAttributedString) -> Void)? {
            didSet {
                guard (oldValue == nil) != (previewAction == nil) else { return }
                setNeedsLayout()
            }
        }

        private let callerIdentifier = UUID()
        private var currentTaskIdentifier: UUID?

        lazy var barView: UIView = .init()
        lazy var scrollView: UIScrollView = .init()
        lazy var languageLabel: UILabel = .init()
        lazy var textView: TextLabelView = .init()
        lazy var copyButton: UIButton = .init()
        lazy var previewButton: UIButton = .init()
        lazy var expandButton: UIButton = .init()
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

        func interactionTarget(at point: CGPoint, event: UIEvent? = nil) -> UIView? {
            for button in [expandButton, previewButton, copyButton] where !button.isHidden {
                let buttonPoint = button.convert(point, from: self)
                guard button.bounds.contains(buttonPoint) else { continue }
                return button.hitTest(buttonPoint, with: event) ?? button
            }

            let textPoint = textView.convert(point, from: self)
            if textView.bounds.contains(textPoint),
               let target = textView.hitTest(textPoint, with: event)
            {
                return target
            }

            let scrollPoint = scrollView.convert(point, from: self)
            if scrollView.bounds.contains(scrollPoint),
               scrollView.contentSize.width > scrollView.bounds.width + 1
                    || scrollView.contentSize.height > scrollView.bounds.height + 1
            {
                return scrollView
            }

            return nil
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard isUserInteractionEnabled,
                  !isHidden,
                  alpha > 0.01,
                  bounds.contains(point)
            else { return nil }

            return interactionTarget(at: point, event: event)
        }

        override var intrinsicContentSize: CGSize {
            let labelSize = languageLabel.intrinsicContentSize
            let barHeight = labelSize.height + CodeViewConfiguration.barPadding * 2
            let textSize = textView.intrinsicContentSize
            let supposedHeight = CodeViewConfiguration.intrinsicHeight(lineCount: displayedLineCount, theme: theme)

            let lineNumberWidth = lineNumberView.intrinsicContentSize.width

            return CGSize(
                width: max(
                    labelSize.width + CodeViewConfiguration.barPadding * 2,
                    lineNumberWidth + textSize.width + CodeViewConfiguration.codePadding * 2
                ),
                height: isCollapsible && !isExpanded
                    ? supposedHeight
                    : max(
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

        @objc func handleExpand(_: UIButton) {
            isExpanded.toggle()
            scrollView.setContentOffset(.zero, animated: false)
            updateExpandButton()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
            preferredHeightDidChange?()
        }

        func updateExpandButton() {
            expandButton.isHidden = !isCollapsible
            let imageName = isExpanded
                ? "arrow.down.right.and.arrow.up.left"
                : "arrow.up.left.and.arrow.down.right"
            expandButton.setImage(
                UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(scale: .small)),
                for: .normal
            )
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView, !isExpanded else { return }
            let labelSize = languageLabel.intrinsicContentSize
            let barHeight = max(languageLabel.font?.lineHeight ?? 16, labelSize.height) + CodeViewConfiguration.barPadding * 2
            lineNumberView.frame.origin.y = barHeight - scrollView.contentOffset.y
        }

        func updateLineNumberView() {
            let font = theme.fonts.code

            let textViewContentHeight = textView.intrinsicContentSize.height

            lineNumberView.configure(
                lineCount: cachedLineCount,
                contentHeight: textViewContentHeight,
                font: font,
                textColor: theme.colors.body.withAlphaComponent(0.5)
            )

            lineNumberView.padding = UIEdgeInsets(
                top: CodeViewConfiguration.codePadding,
                left: CodeViewConfiguration.lineNumberPadding,
                bottom: CodeViewConfiguration.codePadding,
                right: CodeViewConfiguration.lineNumberPadding
            )
        }
    }

    extension CodeView: TextLabel.AttachmentRepresentable {
        func attributedStringRepresentation() -> NSAttributedString {
            textView.attributedText
        }
    }

#elseif canImport(AppKit)
    import AppKit

    final class CodeView: NSView {
        private var needsTextRebuild = false

        var theme: MarkdownTheme = .default {
            didSet {
                languageLabel.font = theme.fonts.code
                textView.selectionBackgroundColor = theme.colors.selectionBackground
                updateLineNumberView()
                if oldValue.fonts.code != theme.fonts.code || oldValue.colors.code != theme.colors.code {
                    needsTextRebuild = true
                }
            }
        }

        var language: String = "" {
            didSet {
                languageLabel.stringValue = language.isEmpty ? "</>" : language
            }
        }

        var highlightMap: CodeHighlighter.HighlightMap = .init() {
            didSet {
                if oldValue != highlightMap {
                    needsTextRebuild = true
                }
            }
        }

        var content: String = "" {
            didSet {
                guard oldValue != content || needsTextRebuild else { return }
                needsTextRebuild = false
                cachedLineCount = max(content.components(separatedBy: .newlines).count, 1)
                textView.attributedText = highlightMap.apply(to: content, with: theme)
                lineNumberView.updateForContent(content)
                updateLineNumberView()
            }
        }

        private var cachedLineCount: Int = 1
        private var highlightedContent: String = ""

        /// Applies content and its highlight map together. Pass `nil` while the
        /// map for `newContent` is still being computed: the previous map is kept
        /// when the new content extends the previously highlighted content
        /// (streaming append), so the colored prefix does not flash back to
        /// plain text on every chunk.
        func setContent(_ newContent: String, highlightMap map: CodeHighlighter.HighlightMap?) {
            if let map {
                highlightedContent = newContent
                highlightMap = map
            } else if !newContent.hasPrefix(highlightedContent) {
                highlightedContent = ""
                highlightMap = .init()
            }
            content = newContent
        }

        var previewAction: ((String?, NSAttributedString) -> Void)? {
            didSet {
                guard (oldValue == nil) != (previewAction == nil) else { return }
                needsLayout = true
            }
        }

        private let callerIdentifier = UUID()
        private var currentTaskIdentifier: UUID?

        lazy var barView: NSView = .init()
        lazy var scrollView: NSScrollView = {
            let sv = HorizontalScrollView()
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

        lazy var textView: TextLabelView = .init()
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

        func interactionTarget(at point: CGPoint) -> NSView? {
            for button in [previewButton, copyButton] where !button.isHidden {
                let buttonPoint = button.convert(point, from: self)
                guard button.bounds.contains(buttonPoint) else { continue }
                return button.hitTest(buttonPoint) ?? button
            }

            let textPoint = textView.convert(point, from: self)
            if textView.bounds.contains(textPoint),
               let target = textView.hitTest(textPoint)
            {
                return target
            }

            let scrollPoint = scrollView.convert(point, from: self)
            if scrollView.bounds.contains(scrollPoint),
               let documentView = scrollView.documentView,
               documentView.bounds.width > scrollView.bounds.width + 1
            {
                return scrollView
            }

            return nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let localPoint = superview.map { convert(point, from: $0) } ?? point
            guard !isHidden, bounds.contains(localPoint) else { return nil }
            return interactionTarget(at: localPoint)
        }

        override var intrinsicContentSize: CGSize {
            let labelSize = languageLabel.intrinsicContentSize
            let barHeight = labelSize.height + CodeViewConfiguration.barPadding * 2
            let textSize = textView.intrinsicContentSize
            let supposedHeight = CodeViewConfiguration.intrinsicHeight(lineCount: CGFloat(cachedLineCount), theme: theme)

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

            let textViewContentHeight = textView.intrinsicContentSize.height

            lineNumberView.configure(
                lineCount: cachedLineCount,
                contentHeight: textViewContentHeight,
                font: font,
                textColor: theme.colors.body.withAlphaComponent(0.5)
            )

            lineNumberView.padding = NSEdgeInsets(
                top: CodeViewConfiguration.codePadding,
                left: CodeViewConfiguration.lineNumberPadding,
                bottom: CodeViewConfiguration.codePadding,
                right: CodeViewConfiguration.lineNumberPadding
            )
        }
    }

    extension CodeView: TextLabel.AttachmentRepresentable {
        func attributedStringRepresentation() -> NSAttributedString {
            textView.attributedText
        }
    }
#endif
