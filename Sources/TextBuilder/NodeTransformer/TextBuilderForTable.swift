//
//  TextBuilderForTable.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForTable: NodeTransformer {
    static let shared = TextBuilderForTable()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case let .table(node) = input else {
            assertionFailure()
            return .init()
        }
        return .init()
    }
}
