//
//  TextBuilderForParagraph.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForParagraph: NodeTransformer {
    static let shared = TextBuilderForParagraph()
    func transform(_ input: NodeWrapper, theme: MarkdownTheme) -> NSAttributedString {
        guard case let .paragraph(node) = input else {
            assertionFailure()
            return .init()
        }

        let result = NSMutableAttributedString(attributedString: transform(children: node.children, theme: theme))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = theme.spacings.general

        result.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: result.full
        )

        result.append(NSAttributedString(string: "\n"))

        return result
    }
}
