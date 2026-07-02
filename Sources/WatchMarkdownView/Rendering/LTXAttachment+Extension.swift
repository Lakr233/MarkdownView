//
//  TextLabel.Attachment+Extension.swift
//  WatchMarkdownView
//

import Foundation
import Litext

private final class HolderAttachment: TextLabel.Attachment {
    private let attrString: NSAttributedString

    init(attrString: NSAttributedString) {
        self.attrString = attrString
        super.init()
    }

    override func attributedStringRepresentation() -> NSAttributedString {
        attrString
    }
}

extension TextLabel.Attachment {
    static func hold(attrString: NSAttributedString) -> TextLabel.Attachment {
        HolderAttachment(attrString: attrString)
    }
}
