//
//  AttributeStringKey.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import CoreText
import Foundation

extension NSAttributedString.Key {
    static let contextView: NSAttributedString.Key = .init("contextView")
    static let contextImage: NSAttributedString.Key = .init("contextImage")
    static let contextIdentifier: NSAttributedString.Key = .init("contextIdentifier")
    static let mathLatexContent: NSAttributedString.Key = .init("mathLatexContent")
    static let coreTextLanguage: NSAttributedString.Key = .init(kCTLanguageAttributeName as String)
}
