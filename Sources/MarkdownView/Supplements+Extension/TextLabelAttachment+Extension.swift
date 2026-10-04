//
//  TextLabelAttachment+Extension.swift
//  MarkdownView
//
//  Created by 秋星桥 on 3/27/25.
//

import Foundation
import Litext

/// An attachment that stands for drawn content and copies as `attrString`.
///
/// Holders carry no view, so two that copy as the same text and take the same
/// room are interchangeable, and compare equal. Rebuilding a document makes new
/// ones; comparing them by value lets the label see the text before an edit as
/// unchanged and keep the lines it typeset for it.
private final class HolderAttachment: TextLabel.Attachment, Hashable {
    /// What equality reads, fixed at creation so it never touches main-actor state.
    private struct Payload: Hashable, @unchecked Sendable {
        let representation: NSAttributedString
        let size: CGSize
        let descent: CGFloat?

        static func == (lhs: Payload, rhs: Payload) -> Bool {
            lhs.size == rhs.size
                && lhs.descent == rhs.descent
                && lhs.representation.isEqual(to: rhs.representation)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(representation.string)
        }
    }

    private nonisolated let payload: Payload

    init(attrString: NSAttributedString, size: CGSize, descent: CGFloat?) {
        payload = .init(
            representation: attrString.copy() as! NSAttributedString,
            size: size,
            descent: descent,
        )
        super.init()
        self.size = size
        self.descent = descent
    }

    override func attributedStringRepresentation() -> NSAttributedString {
        payload.representation
    }

    nonisolated static func == (lhs: HolderAttachment, rhs: HolderAttachment) -> Bool {
        lhs === rhs || lhs.payload == rhs.payload
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(payload)
    }
}

extension TextLabel.Attachment {
    /// An attachment that copies as `attrString` and reserves `size`. Holders
    /// compare by value, so pass the size and descent here rather than setting
    /// them afterwards.
    static func hold(
        attrString: NSAttributedString,
        size: CGSize = .zero,
        descent: CGFloat? = nil,
    ) -> TextLabel.Attachment {
        HolderAttachment(attrString: attrString, size: size, descent: descent)
    }
}
