//
//  Created by ktiays on 2025/1/20.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Combine
import MarkdownParser
import UIKit

public protocol MarkdownTextViewDelegate: AnyObject {
    func markdownTextView(
        _ textView: MarkdownTextView,
        didInteractWith link: LinkPayload,
        range: NSRange,
        location: CGPoint
    )

    func markdownTextView(
        _ textView: MarkdownTextView,
        didRequestPreviewFor language: String?,
        content: NSAttributedString
    )
}

public extension MarkdownTextViewDelegate {
    func markdownTextView(
        _: MarkdownTextView,
        didInteractWith _: LinkPayload,
        range _: NSRange,
        location _: CGPoint
    ) {}

    func markdownTextView(
        _: MarkdownTextView,
        didRequestPreviewFor _: String?,
        content _: NSAttributedString
    ) {}
}

public final class MarkdownTextView: UIView {
    public weak var delegate: MarkdownTextViewDelegate?

    public internal(set) var document: PreprocessedContent = .init()
    let contentTextView = MarkdownContentTextView()
    public var textView: UITextView { contentTextView }
    public var theme: MarkdownTheme = .default {
        didSet { setMarkdown(document) } // update it
    }

    public internal(set) weak var trackedScrollView: UIScrollView? // for selection updating

    var contextViews: [UIView] = []
    var cancellables = Set<AnyCancellable>()
    let contentSubject = CurrentValueSubject<PreprocessedContent, Never>(.init())
    public var throttleInterval: TimeInterval? = 1 / 20 { // x fps
        didSet { setupCombine() }
    }

    let viewProvider: ReusableViewProvider

    public init(viewProvider: ReusableViewProvider = .init()) {
        self.viewProvider = viewProvider
        super.init(frame: .zero)
        textView.interactions.removeAll { interaction in
            if interaction is UIDropInteraction { return true }
            if interaction is UIDragInteraction { return true }
            return false
        }
        contentTextView.backgroundColor = .clear
        contentTextView.delegate = self
        addSubview(contentTextView)
        setupCombine()
    }

    deinit {
        viewProvider.removeAll()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        contentTextView.frame = bounds
        contentTextView.textContainer.size = CGSize(
            width: max(0, bounds.width - contentTextView.textContainerInset.left - contentTextView.textContainerInset.right),
            height: .greatestFiniteMagnitude
        )
    }

    public func boundingSize(for width: CGFloat) -> CGSize {
        contentTextView.textContainer.size = CGSize(
            width: max(0, width - contentTextView.textContainerInset.left - contentTextView.textContainerInset.right),
            height: .greatestFiniteMagnitude
        )
        let fitting = contentTextView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    public func setMarkdownManually(_ content: PreprocessedContent) {
        assert(Thread.isMainThread)
        resetCombine()
        use(content)
    }

    public func setMarkdown(_ content: PreprocessedContent) {
        contentSubject.send(content)
    }

    public func reset() {
        assert(Thread.isMainThread)
        resetCombine()
        flushRenderedContent()
        let empty = PreprocessedContent()
        contentSubject.send(empty)
        use(empty)
        setupCombine()
    }

    public func bindContentOffset(from scrollView: UIScrollView?) {
        trackedScrollView = scrollView
    }
}
