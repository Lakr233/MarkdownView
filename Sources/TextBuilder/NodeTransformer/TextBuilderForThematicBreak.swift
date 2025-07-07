//
//  TextBuilderForThematicBreak.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

class TextBuilderForThematicBreak: NodeTransformer {
    static let shared = TextBuilderForThematicBreak()
    func transform(_ input: NodeWrapper, theme _: MarkdownTheme) -> NSAttributedString {
        guard case .thematicBreak = input else {
            assertionFailure()
            return .init()
        }

//        let attachment = TextAttachment(
//            viewProvider: ThematicBreakViewProvider(),
//            userObject: theme
//        )
//        return NSAttributedString(attachment: attachment)
        return .init()
    }
}

class ThematicBreakView: UIView {
    init(color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = color
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
