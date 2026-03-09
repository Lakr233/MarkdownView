//
//  LTXAttachment+Extension.swift
//  WatchMarkdownView
//

import Foundation
import Litext

private final class LTXHolderAttachment: LTXAttachment {
    private let attrString: NSAttributedString

    init(attrString: NSAttributedString) {
        self.attrString = attrString
        super.init()
    }

    override func attributedStringRepresentation() -> NSAttributedString {
        attrString
    }
}

extension LTXAttachment {
    static func hold(attrString: NSAttributedString) -> LTXAttachment {
        LTXHolderAttachment(attrString: attrString)
    }
}
