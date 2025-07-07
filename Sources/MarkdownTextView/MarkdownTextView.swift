// The Swift Programming Language
// https://docs.swift.org/swift-book

import Litext
import markdown_core
import markdown_core_ast
import UIKit

public class MarkdownTextView: UIView {
    let textView = LTXLabel()

    public var preferredMaxLayoutWidth: CGFloat {
        get { textView.preferredMaxLayoutWidth }
        set {
            textView.preferredMaxLayoutWidth = newValue
            invalidateIntrinsicContentSize()
        }
    }

    override public var intrinsicContentSize: CGSize { textView.intrinsicContentSize }

    public init() {
        super.init(frame: .zero)
        addSubview(textView)
        textView.backgroundColor = .clear
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
    }

    public func set(attributedText: NSAttributedString) {
        textView.attributedText = attributedText
    }

    // suggested to run at background thread
    public func set(document: String, theme: MarkdownTheme) {
        textView.attributedText = (try? TextBuilder(theme: theme).build(document)) ?? .init()
    }

    // suggested to run at background thread
    public func set(ast: Root, theme: MarkdownTheme) {
        textView.attributedText = TextBuilder(theme: theme).build(ast)
    }
}
