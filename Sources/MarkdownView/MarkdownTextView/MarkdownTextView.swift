//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Combine
import CoreText
import Litext
import MarkdownParser

#if canImport(UIKit)
    import UIKit

    public final class MarkdownTextView: UIView {
        public var linkHandler: ((LinkPayload, NSRange, CGPoint) -> Void)?
        public var codePreviewHandler: ((String?, NSAttributedString) -> Void)?

        public internal(set) var content: MarkdownContent = .init()

        @available(*, deprecated, renamed: "content")
        public var document: MarkdownContent { content }
        public let textLabelView: TextLabelView = .init()

        @available(*, deprecated, renamed: "textLabelView")
        public var textView: TextLabelView { textLabelView }
        public var theme: MarkdownTheme = .default {
            didSet {
                guard oldValue != theme else { return }
                textLabelView.selectionBackgroundColor = theme.colors.selectionBackground
                use(content)
            }
        }

        /// Scroll view used for auto-scrolling while the user drags a text selection.
        public weak var trackedScrollView: UIScrollView?

        var contextViews: [UIView] = []
        var cancellables = Set<AnyCancellable>()
        let contentSubject = CurrentValueSubject<MarkdownContent, Never>(.init())
        public var throttleInterval: TimeInterval? = 1 / 20 { // x fps
            didSet { setupCombine() }
        }

        let viewProvider: ReusableViewProvider

        public init(viewProvider: ReusableViewProvider = .init()) {
            self.viewProvider = viewProvider
            super.init(frame: .zero)
            textLabelView.isSelectable = true
            textLabelView.backgroundColor = .clear
            textLabelView.selectionBackgroundColor = theme.colors.selectionBackground
            textLabelView.delegate = self
            textLabelView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(textLabelView)
            NSLayoutConstraint.activate([
                textLabelView.leadingAnchor.constraint(equalTo: leadingAnchor),
                textLabelView.trailingAnchor.constraint(equalTo: trailingAnchor),
                textLabelView.topAnchor.constraint(equalTo: topAnchor),
                textLabelView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            setupCombine()
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            textLabelView.preferredMaxLayoutWidth = bounds.width
        }

        override public var intrinsicContentSize: CGSize {
            textLabelView.intrinsicContentSize
        }

        public func boundingSize(for width: CGFloat) -> CGSize {
            textLabelView.preferredMaxLayoutWidth = width
            return textLabelView.intrinsicContentSize
        }

        /// Replaces the displayed content immediately, bypassing the update throttle.
        public func setContentImmediately(_ content: MarkdownContent) {
            assert(Thread.isMainThread)
            resetCombine()
            contentSubject.send(content)
            use(content)
            setupCombine()
        }

        /// Replaces the displayed content, coalesced by ``throttleInterval``.
        /// Safe to call at high frequency (e.g. while streaming).
        public func setContent(_ content: MarkdownContent) {
            contentSubject.send(content)
        }

        /// Parses and displays markdown text in one step.
        /// For streaming or off-main-thread parsing, build a ``MarkdownContent``
        /// yourself and use ``setContent(_:)``.
        public func setMarkdown(_ markdown: String) {
            setContentImmediately(.init(markdown: markdown, theme: theme))
        }

        @available(*, deprecated, renamed: "setContentImmediately(_:)")
        public func setMarkdownManually(_ content: MarkdownContent) {
            setContentImmediately(content)
        }

        @available(*, deprecated, renamed: "setContent(_:)")
        public func setMarkdown(_ content: MarkdownContent) {
            setContent(content)
        }

        public func reset() {
            assert(Thread.isMainThread)
            resetCombine()
            contentSubject.send(.init())
            use(.init())
            setupCombine()
        }

        @available(*, deprecated, renamed: "trackedScrollView")
        public func bindContentOffset(from scrollView: UIScrollView?) {
            trackedScrollView = scrollView
        }
    }

#elseif canImport(AppKit)
    import AppKit

    public final class MarkdownTextView: NSView {
        public var linkHandler: ((LinkPayload, NSRange, CGPoint) -> Void)?
        public var codePreviewHandler: ((String?, NSAttributedString) -> Void)?

        public internal(set) var content: MarkdownContent = .init()

        @available(*, deprecated, renamed: "content")
        public var document: MarkdownContent { content }
        public let textLabelView: TextLabelView = .init()

        @available(*, deprecated, renamed: "textLabelView")
        public var textView: TextLabelView { textLabelView }
        public var theme: MarkdownTheme = .default {
            didSet {
                guard oldValue != theme else { return }
                textLabelView.selectionBackgroundColor = theme.colors.selectionBackground
                use(content)
            }
        }

        /// Scroll view used for auto-scrolling while the user drags a text selection.
        public weak var trackedScrollView: NSScrollView?

        var contextViews: [NSView] = []
        var cancellables = Set<AnyCancellable>()
        let contentSubject = CurrentValueSubject<MarkdownContent, Never>(.init())
        public var throttleInterval: TimeInterval? = 1 / 20 { // x fps
            didSet { setupCombine() }
        }

        let viewProvider: ReusableViewProvider

        public init(viewProvider: ReusableViewProvider = .init()) {
            self.viewProvider = viewProvider
            super.init(frame: .zero)
            textLabelView.isSelectable = true
            textLabelView.selectionBackgroundColor = theme.colors.selectionBackground
            textLabelView.delegate = self
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            textLabelView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(textLabelView)
            NSLayoutConstraint.activate([
                textLabelView.leadingAnchor.constraint(equalTo: leadingAnchor),
                textLabelView.trailingAnchor.constraint(equalTo: trailingAnchor),
                textLabelView.topAnchor.constraint(equalTo: topAnchor),
                textLabelView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            setupCombine()
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override public var isFlipped: Bool {
            true
        }

        override public func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            use(content)
        }

        override public func layout() {
            super.layout()
            textLabelView.preferredMaxLayoutWidth = bounds.width
        }

        override public var intrinsicContentSize: CGSize {
            textLabelView.intrinsicContentSize
        }

        public func boundingSize(for width: CGFloat) -> CGSize {
            textLabelView.preferredMaxLayoutWidth = width
            return textLabelView.intrinsicContentSize
        }

        /// Replaces the displayed content immediately, bypassing the update throttle.
        public func setContentImmediately(_ content: MarkdownContent) {
            assert(Thread.isMainThread)
            resetCombine()
            contentSubject.send(content)
            use(content)
            setupCombine()
        }

        /// Replaces the displayed content, coalesced by ``throttleInterval``.
        /// Safe to call at high frequency (e.g. while streaming).
        public func setContent(_ content: MarkdownContent) {
            contentSubject.send(content)
        }

        /// Parses and displays markdown text in one step.
        /// For streaming or off-main-thread parsing, build a ``MarkdownContent``
        /// yourself and use ``setContent(_:)``.
        public func setMarkdown(_ markdown: String) {
            setContentImmediately(.init(markdown: markdown, theme: theme))
        }

        @available(*, deprecated, renamed: "setContentImmediately(_:)")
        public func setMarkdownManually(_ content: MarkdownContent) {
            setContentImmediately(content)
        }

        @available(*, deprecated, renamed: "setContent(_:)")
        public func setMarkdown(_ content: MarkdownContent) {
            setContent(content)
        }

        public func reset() {
            assert(Thread.isMainThread)
            resetCombine()
            contentSubject.send(.init())
            use(.init())
            setupCombine()
        }

        @available(*, deprecated, renamed: "trackedScrollView")
        public func bindContentOffset(from scrollView: NSScrollView?) {
            trackedScrollView = scrollView
        }
    }
#endif
