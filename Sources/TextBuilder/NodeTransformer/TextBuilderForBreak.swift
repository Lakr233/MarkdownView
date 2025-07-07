//
//  TextBuilderForBreak.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForBreak: NodeTransformer {
    static let shared = TextBuilderForBreak()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case .breakNode = input else {
            assertionFailure()
            return .init()
        }

        return NSAttributedString(string: "\n")
    }
}
