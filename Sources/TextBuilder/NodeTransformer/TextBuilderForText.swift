//
//  TextBuilderForText.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForText: NodeTransformer {
    static let shared = TextBuilderForText()
    func transform(_ input: NodeWrapper, theme: MarkdownTheme) -> NSAttributedString {
        guard case let .text(node) = input else {
            assertionFailure()
            return .init()
        }
        return NSAttributedString(
            string: node.value,
            attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
            ]
        )
    }
}
