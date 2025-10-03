//
//  MarkdownContentTextView.swift
//  MarkdownView
//
//  Created by GitHub Copilot on 2025/10/13.
//

import Foundation
import UIKit

final class MarkdownContentTextView: UITextView {
    private let markdownTextStorage = NSTextStorage()
    private let markdownLayoutManager = MarkdownLayoutManager()
    private let markdownTextContainer = NSTextContainer()

    private var hostedViews: Set<UIView> = []
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
        markdownTextContainer.widthTracksTextView = true
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        backgroundColor = .clear
        isScrollEnabled = false
        isEditable = false
        isSelectable = true
        delaysContentTouches = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        linkTextAttributes = [:]
    }

    func apply(document: NSAttributedString, hostedViews newHostedViews: [UIView]) {
        hostedViews.forEach { $0.removeFromSuperview() }
        hostedViews.removeAll()

        let mutable = NSMutableAttributedString(attributedString: document)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.markdownAttachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? MarkdownAttachment else { return }
            let textAttachment = attachment.resolvedTextAttachment()
            textAttachment.hostedView = attachment.view
            mutable.addAttribute(.attachment, value: textAttachment, range: range)
        }

        markdownTextStorage.setAttributedString(mutable)
        markdownLayoutManager.ensureLayout(for: markdownTextContainer)

        for view in newHostedViews {
            if view.superview != self {
                addSubview(view)
            }
            hostedViews.insert(view)
        }

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let availableWidth = bounds.width - textContainerInset.left - textContainerInset.right
        if availableWidth != lastLayoutWidth {
            lastLayoutWidth = availableWidth
            if markdownTextStorage.length > 0 {
                let fullRange = NSRange(location: 0, length: markdownTextStorage.length)
                markdownLayoutManager.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
            }
        }

        markdownTextContainer.size = CGSize(width: max(0, availableWidth), height: .greatestFiniteMagnitude)
        markdownLayoutManager.ensureLayout(for: markdownTextContainer)
        layoutAttachmentViews()
    }

    private func layoutAttachmentViews() {
        guard !hostedViews.isEmpty else { return }
        markdownLayoutManager.ensureLayout(for: markdownTextContainer)
        let fullRange = NSRange(location: 0, length: markdownTextStorage.length)
        markdownTextStorage.enumerateAttribute(.markdownAttachment, in: fullRange, options: []) { value, range, _ in
            guard let attachment = value as? MarkdownAttachment, let view = attachment.view else { return }
            let glyphRange = markdownLayoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }

            var lastFrame: CGRect?
            markdownLayoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                lastFrame = usedRect
            }
            guard let usedRect = lastFrame else { return }

            let indentation = usedRect.minX
            let containerWidth = bounds.width - textContainerInset.left - textContainerInset.right
            let availableWidth = max(0, containerWidth - indentation)
            let width = availableWidth
            let desiredHeight = max(view.intrinsicContentSize.height, attachment.size.height)
            let height = max(usedRect.height, desiredHeight)
            let frame = CGRect(
                x: textContainerInset.left + indentation,
                y: textContainerInset.top + usedRect.minY,
                width: width,
                height: height
            )
            if view.superview != self { addSubview(view) }
            view.frame = frame
        }
    }

    func rect(for range: NSRange) -> CGRect? {
        guard let start = position(from: beginningOfDocument, offset: range.location) else { return nil }
        guard let end = position(from: start, offset: range.length) else { return nil }
        guard let textRange = textRange(from: start, to: end) else { return nil }
        return firstRect(for: textRange)
    }
}
