//
//  TextBuilderForStrong.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForStrong: NodeTransformer {
    static let shared = TextBuilderForStrong()
    func transform(_ input: NodeWrapper, theme: MarkdownTheme) -> NSAttributedString {
        guard case let .strong(node) = input else {
            assertionFailure()
            return .init()
        }

        let result = NSMutableAttributedString(attributedString: transform(children: node.children, theme: theme))
        result.addAttribute(
            .font,
            value: theme.fonts.bold,
            range: result.full
        )
        return result
    }
}
