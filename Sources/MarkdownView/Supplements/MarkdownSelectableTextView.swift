//
//  MarkdownSelectableTextView.swift
//  MarkdownView
//
//  Created by GitHub Copilot on 2025/10/13.
//

import UIKit

final class MarkdownSelectableTextView: UITextView {
    var preferredMaxLayoutWidth: CGFloat = .greatestFiniteMagnitude {
        didSet {
            if preferredMaxLayoutWidth != oldValue {
                invalidateIntrinsicContentSize()
                setNeedsLayout()
            }
        }
    }

    private let markdownTextStorage = NSTextStorage()
    private let markdownLayoutManager = MarkdownLayoutManager()
    private let markdownTextContainer = NSTextContainer()
    private var hostedViews: Set<UIView> = []
    private var storedAttributedText: NSAttributedString = .init()
    private var lastLayoutWidth: CGFloat = 0

    override init(frame: CGRect, textContainer _: NSTextContainer?) {
        markdownLayoutManager.addTextContainer(markdownTextContainer)
        markdownTextStorage.addLayoutManager(markdownLayoutManager)
        super.init(frame: frame, textContainer: markdownTextContainer)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear
        isEditable = false
        isScrollEnabled = false
        isSelectable = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        linkTextAttributes = [:]
        markdownTextContainer.lineFragmentPadding = 0
    }

    override var attributedText: NSAttributedString! {
        get { storedAttributedText }
        set { apply(markdownAttributedString: newValue ?? NSAttributedString()) }
    }

    func apply(markdownAttributedString newValue: NSAttributedString) {
        hostedViews.forEach { $0.removeFromSuperview() }
        hostedViews.removeAll()

        storedAttributedText = newValue
        let mutable = NSMutableAttributedString(attributedString: newValue)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.markdownAttachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? MarkdownAttachment else { return }
            let textAttachment = attachment.resolvedTextAttachment()
            textAttachment.hostedView = attachment.view
            mutable.addAttribute(.attachment, value: textAttachment, range: range)
            if let view = attachment.view {
                hostedViews.insert(view)
                if view.superview != self {
                    addSubview(view)
                }
            }
        }

        markdownTextStorage.setAttributedString(mutable)
        markdownLayoutManager.ensureLayout(for: markdownTextContainer)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let widthConstraint = preferredMaxLayoutWidth.isFinite
            ? preferredMaxLayoutWidth
            : max(bounds.width, 0)
        if widthConstraint != lastLayoutWidth {
            lastLayoutWidth = widthConstraint
            if markdownTextStorage.length > 0 {
                let range = NSRange(location: 0, length: markdownTextStorage.length)
                markdownLayoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
            }
        }
        markdownTextContainer.size = CGSize(
            width: max(0, widthConstraint),
            height: .greatestFiniteMagnitude
        )
        markdownLayoutManager.ensureLayout(for: markdownTextContainer)
        layoutHostedViews()
    }

    override var intrinsicContentSize: CGSize {
        let widthConstraint = preferredMaxLayoutWidth.isFinite
            ? preferredMaxLayoutWidth
            : max(bounds.width, 0)
        markdownTextContainer.size = CGSize(
            width: max(0, widthConstraint),
            height: .greatestFiniteMagnitude
        )
        markdownLayoutManager.ensureLayout(for: markdownTextContainer)
        let usedRect = markdownLayoutManager.usedRect(for: markdownTextContainer)
        return CGSize(width: ceil(usedRect.width), height: ceil(usedRect.height))
    }

    private func layoutHostedViews() {
        guard !hostedViews.isEmpty else { return }
        let fullRange = NSRange(location: 0, length: markdownTextStorage.length)
        markdownTextStorage.enumerateAttribute(.markdownAttachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? MarkdownAttachment, let view = attachment.view, hostedViews.contains(view) else { return }
            let glyphRange = markdownLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }

            var usedFragment: CGRect?
            markdownLayoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                usedFragment = usedRect
            }
            guard let usedRect = usedFragment else { return }

            let indentation = usedRect.minX
            let availableWidth = max(0, markdownTextContainer.size.width - indentation)
            let frame = CGRect(
                x: indentation,
                y: usedRect.minY,
                width: availableWidth,
                height: max(usedRect.height, max(view.intrinsicContentSize.height, attachment.size.height))
            )
            view.frame = frame
            if view.superview != self {
                addSubview(view)
            }
        }
    }
}
