//
//  TextBuilderForEmphasis.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForEmphasis: NodeTransformer {
    static let shared = TextBuilderForEmphasis()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case let .emphasis(node) = input else {
            assertionFailure()
            return .init()
        }

        return .init()
    }
}
