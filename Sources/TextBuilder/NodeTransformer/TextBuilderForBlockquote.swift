//
//  TextBuilderForBlockquote.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit
import Litext

class TextBuilderForBlockquote: NodeTransformer {
    static let shared = TextBuilderForBlockquote()
    func transform(_ input: NodeWrapper, theme: MarkdownTheme) -> NSAttributedString {
        guard case let .blockquote(node) = input else {
            assertionFailure()
            return .init()
        }
        let attachment = LTXAttachment(viewProvider: BlockquoteViewProvider(node: node, theme: theme))
        let text = input.createAttachmentHoldingString(attachment: attachment, theme: theme)
        input.insertNewline(into: text, theme: theme)
        return text
    }
}

class BlockquoteView: UIView {
    let lineView = UIView()
    let label = MarkdownTextView()
    let theme: MarkdownTheme
    
    init(theme: MarkdownTheme) {
        self.theme = theme
        super.init(frame: .zero)
        
        lineView.backgroundColor = theme.colors.codeBackground
        lineView.layer.cornerRadius = 2
        addSubview(lineView)
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let superview else { return }
        lineView.frame = .init(x: 0, y: 0, width: 4, height: bounds.height)
        label.frame = .init(x: 8, y: 0, width: bounds.width - 8, height: bounds.height)
    }
    
    func use(node: Blockquote) {
        label.set(ast: node.children, theme: theme)
    }
}

class BlockquoteViewProvider: LTXAttachmentViewProvider {
    let node: Blockquote
    let theme: MarkdownTheme

    init(node: Blockquote, theme: MarkdownTheme) {
        self.node = node
        self.theme = theme
    }
    
    func reuseIdentifier() -> String {
        #fileID
    }
    
    func createView() -> Litext.LTXPlatformView {
        BlockquoteView(theme: theme)
    }
    
    func configureView(_ view: Litext.LTXPlatformView, for attachment: Litext.LTXAttachment) {
        (view as! BlockquoteView).use(node: node)
    }
    
    func boundingSize(for attachment: Litext.LTXAttachment) -> CGSize {
        return .init(width: 128, height: 100)
    }
    
    func textRepresentation() -> String {
        String(describing: node)
    }
}
