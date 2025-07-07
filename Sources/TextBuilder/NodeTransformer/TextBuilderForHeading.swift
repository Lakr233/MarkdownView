//
//  TextBuilderForHeading.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForHeading: NodeTransformer {
    static let shared = TextBuilderForHeading()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case let .heading(node) = input else {
            assertionFailure()
            return .init()
        }

        return .init()
    }
}
