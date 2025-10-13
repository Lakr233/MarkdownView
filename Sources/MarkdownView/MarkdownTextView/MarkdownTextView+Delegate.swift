//
//  MarkdownTextView+Delegate.swift
//  MarkdownView
//
//  Created by GitHub Copilot on 2025/10/13.
//

import UIKit

extension MarkdownTextView: UITextViewDelegate {
    public func textViewDidChangeSelection(_ textView: UITextView) {
        guard textView === contentTextView else { return }
        guard let scrollView = trackedScrollView else { return }
        if scrollView.contentSize.height <= scrollView.bounds.height { return }
        guard let selectedRange = contentTextView.selectedTextRange else { return }

        let caretRect = contentTextView.caretRect(for: selectedRange.end)
        let targetRect = caretRect.insetBy(dx: 0, dy: -32)
        let convertedRect = contentTextView.convert(targetRect, to: scrollView)
        scrollView.scrollRectToVisible(convertedRect, animated: false)
    }

    public func textView(
        _: UITextView,
        shouldInteractWith _: URL,
        in characterRange: NSRange,
        interaction _: UITextItemInteraction
    ) -> Bool {
        handleLinkInteraction(at: characterRange)
        return false
    }

    public func textView(
        _: UITextView,
        shouldInteractWith textAttachment: NSTextAttachment,
        in characterRange: NSRange,
        interaction _: UITextItemInteraction
    ) -> Bool {
        _ = textAttachment
        handleLinkInteraction(at: characterRange)
        return false
    }

    public func textView(
        _: UITextView,
        shouldInteractWith _: URL,
        in characterRange: NSRange
    ) -> Bool {
        handleLinkInteraction(at: characterRange)
        return false
    }

    public func textView(
        _: UITextView,
        shouldInteractWith textAttachment: NSTextAttachment,
        in characterRange: NSRange
    ) -> Bool {
        _ = textAttachment
        handleLinkInteraction(at: characterRange)
        return false
    }

    private func handleLinkInteraction(at range: NSRange) {
        guard range.location != NSNotFound else { return }
        guard let attributedText = contentTextView.attributedText, attributedText.length > range.location else { return }

        let attributes = attributedText.attributes(at: range.location, effectiveRange: nil)
        guard let value = attributes[.link] else { return }

        let payload: LinkPayload? = if let url = value as? URL {
            .url(url)
        } else if let string = value as? String {
            .string(string)
        } else {
            nil
        }

        guard let payload else { return }

        let rect = contentTextView.rect(for: range) ?? .zero
        let location = CGPoint(x: rect.midX, y: rect.midY)
        let convertedLocation = contentTextView.convert(location, to: self)
        delegate?.markdownTextView(
            self,
            didInteractWith: payload,
            range: range,
            location: convertedLocation
        )
    }
}
