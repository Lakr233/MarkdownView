//
//  TextBuilderForDefinition.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForDefinition: NodeTransformer {
    static let shared = TextBuilderForDefinition()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case let .definition(node) = input else {
            assertionFailure()
            return .init()
        }
        return .init()
    }
}
