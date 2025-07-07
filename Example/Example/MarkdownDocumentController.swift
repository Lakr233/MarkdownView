//
//  MarkdownDocumentController.swift
//  Example
//
//  Created by 秋星桥 on 7/8/25.
//

import markdown_core
import markdown_core_ast
import MarkdownView
import UIKit

class MarkdownDocumentController: UIViewController {
    let root: Root
    init(testCase: AllTestCases) {
        root = testCase.createTestableAstNode()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    let scrollView = UIScrollView()
    let markdownView = MarkdownTextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        edgesForExtendedLayout = []
        view.addSubview(scrollView)
        scrollView.autoresizingMask = []
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.clipsToBounds = true
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        scrollView.addSubview(markdownView)
        markdownView.set(ast: root, theme: .default)

        view.layoutIfNeeded()

        markdownView.layer.borderColor = UIColor.systemGray.cgColor
        markdownView.layer.borderWidth = 1
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let inset: CGFloat = 8
        markdownView.preferredMaxLayoutWidth = scrollView.frame.width - inset * 2
        let size = markdownView.intrinsicContentSize
        markdownView.frame = .init(
            x: inset,
            y: inset,
            width: scrollView.frame.width - inset * 2,
            height: size.height
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentSize = .init(width: 0, height: markdownView.frame.maxY)
    }
}
