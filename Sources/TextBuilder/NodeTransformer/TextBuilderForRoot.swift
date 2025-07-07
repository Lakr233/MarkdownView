//
//  TextBuilderForRoot.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForRoot: NodeTransformer {
    static let shared = TextBuilderForRoot()
    func transform(_ input: NodeWrapper, theme: MarkdownTheme) -> NSAttributedString {
        guard case let .root(node) = input else {
            assertionFailure()
            return .init()
        }
        return transform(children: node.children, theme: theme)
    }
}
