//
//  TextBuilderForLinkReference.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForLinkReference: NodeTransformer {
    static let shared = TextBuilderForLinkReference()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case let .linkReference(node) = input else {
            assertionFailure()
            return .init()
        }
        return .init()
    }
}
