//
//  TextBuilderForList.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForList: NodeTransformer {
    static let shared = TextBuilderForList()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case let .list(node) = input else {
            assertionFailure()
            return .init()
        }
        return .init()
    }
}
