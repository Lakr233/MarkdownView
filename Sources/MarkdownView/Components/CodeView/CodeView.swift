//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext

final class CodeView: PlatformView {
    // MARK: - CONTENT

    private var needsTextRebuild = false

    var theme: MarkdownTheme = .default {
        didSet {
            languageLabel.font = theme.fonts.code
            applyBackgroundColors()
            textView.selectionBackgroundColor = theme.colors.selectionBackground
            updateLineNumberView()
            if oldValue.fonts.code != theme.fonts.code
                || oldValue.colors.code != theme.colors.code
                || oldValue.syntax != theme.syntax
            {
                needsTextRebuild = true
            }
        }
    }

    var language: String = "" {
        didSet {
            #if canImport(UIKit)
                languageLabel.text = language.isEmpty ? "</>" : language
            #elseif canImport(AppKit)
                languageLabel.stringValue = language.isEmpty ? "</>" : language
            #endif
            // The label is sized in layout.
            if oldValue != language {
                resetCopyFeedback()
                reloadActions()
                markNeedsLayout()
            }
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
            // A reused view takes another block, and a streaming block's
            // copy is already stale; either way it no longer shows "copied".
            if oldValue != content {
                resetCopyFeedback()
            }
            guard oldValue != content || needsTextRebuild else { return }
            needsTextRebuild = false
            cachedLineCount = max(content.components(separatedBy: .newlines).count, 1)
            textView.attributedText = highlightMap.apply(to: content, with: theme)
            lineNumberView.updateForContent(content)
            updateLineNumberView()
            // A line can grow without the frame changing, and the text
            // view and scroll extent are sized in layout.
            markNeedsLayout()
        }
    }

    private var cachedLineCount: Int = 1
    private var highlightedContent: String = ""

    /// The highlight cache key of the block this view shows.
    var highlightKey: Int?
    /// The key whose map colours the text now, or nil while the colours
    /// on screen are a stale prefix's or none at all.
    private(set) var highlightedKey: Int?

    /// Applies content and its highlight map together. Pass `nil` while the
    /// map for `newContent` is still being computed: the previous map is kept
    /// when the new content extends the previously highlighted content
    /// (streaming append), so the colored prefix does not flash back to
    /// plain text on every chunk.
    func setContent(
        _ newContent: String,
        highlightMap map: CodeHighlighter.HighlightMap?,
        highlightKey key: Int? = nil
    ) {
        if let map {
            highlightedContent = newContent
            highlightedKey = key
            highlightMap = map
        } else {
            highlightedKey = nil
            if !newContent.hasPrefix(highlightedContent) {
                highlightedContent = ""
                highlightMap = .init()
            }
        }
        content = newContent
    }

    // MARK: CONTENT -

    var previewAction: ((String?, NSAttributedString) -> Void)? {
        didSet {
            guard (oldValue == nil) != (previewAction == nil) else { return }
            markNeedsLayout()
        }
    }

    /// Supplies the host's own buttons, asked again when the language changes.
    weak var actionProvider: CodeBlockActionProvider? {
        didSet {
            guard oldValue !== actionProvider else { return }
            reloadActions()
        }
    }

    var actions: [CodeBlockAction] = []

    private let callerIdentifier = UUID()
    private var currentTaskIdentifier: UUID?

    lazy var barView: PlatformView = .init()
    #if canImport(UIKit)
        lazy var scrollView: HorizontalClippingScrollView = .init()
        lazy var languageLabel: UILabel = .init()
        lazy var copyButton: UIButton = .init()
        lazy var downloadButton: UIButton = .init()
        lazy var previewButton: UIButton = .init()
        var actionButtons: [UIButton] = []
    #elseif canImport(AppKit)
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

        lazy var copyButton: NSButton = .init(title: "", target: nil, action: nil)
        lazy var downloadButton: NSButton = .init(title: "", target: nil, action: nil)
        lazy var previewButton: NSButton = .init(title: "", target: nil, action: nil)
        var actionButtons: [NSButton] = []
    #endif

    lazy var textView: TextLabelView = .init()
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

    #if canImport(UIKit)
        override func layoutSubviews() {
            super.layoutSubviews()
            performLayout()
            updateLineNumberView()
        }
    #elseif canImport(AppKit)
        override var isFlipped: Bool {
            true
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            applyBackgroundColors()
        }

        override func layout() {
            super.layout()
            performLayout()
            updateLineNumberView()
        }
    #endif

    #if canImport(UIKit)
        func interactionTarget(at point: CGPoint, event: UIEvent? = nil) -> UIView? {
            for button in barButtons where !button.isHidden {
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
    #elseif canImport(AppKit)
        func interactionTarget(at point: CGPoint) -> NSView? {
            for button in barButtons where !button.isHidden {
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
    #endif

    override var intrinsicContentSize: CGSize {
        let labelSize = languageLabel.intrinsicContentSize
        let barHeight = labelSize.height + CodeViewConfiguration.barPadding * 2
        let textSize = textView.intrinsicContentSize
        let supposedHeight = CodeViewConfiguration.intrinsicHeight(lineCount: cachedLineCount, theme: theme)

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

    #if canImport(UIKit)
        @objc func handleCopy(_: UIButton) {
            UIPasteboard.general.string = content
            #if !os(visionOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            showCopyFeedback()
        }

        @objc func handlePreview(_: UIButton) {
            #if !os(visionOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            previewAction?(language, textView.attributedText)
        }

        @objc func handleDownload(_: UIButton) {
            downloadCode()
        }
    #elseif canImport(AppKit)
        @objc func handleCopy(_: Any?) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
            showCopyFeedback()
        }

        @objc func handlePreview(_: Any?) {
            previewAction?(language, textView.attributedText)
        }

        @objc func handleDownload(_: Any?) {
            downloadCode()
        }
    #endif

    func updateLineNumberView() {
        let font = theme.fonts.code

        let textViewContentHeight = textView.intrinsicContentSize.height

        lineNumberView.configure(
            lineCount: cachedLineCount,
            contentHeight: textViewContentHeight,
            font: font,
            textColor: theme.colors.body.withAlphaComponent(0.5)
        )

        lineNumberView.padding = .init(
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
