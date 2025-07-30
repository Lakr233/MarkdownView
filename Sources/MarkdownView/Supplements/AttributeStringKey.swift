//
//  AttributeStringKey.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import Foundation

extension NSAttributedString.Key {
    static let contextView: NSAttributedString.Key = .init("contextView")
    static let contextImage: NSAttributedString.Key = .init("contextImage")
    static let contextIdentifier: NSAttributedString.Key = .init("contextIdentifier")
    static let blockquoteDepth: NSAttributedString.Key = .init("blockquoteDepth")
    static let isBlockquoteStart: NSAttributedString.Key = .init("isBlockquoteStart")
    static let isBlockquoteEnd: NSAttributedString.Key = .init("isBlockquoteEnd")
}
