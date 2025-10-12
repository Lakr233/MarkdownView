//
//  DocumentDetailController.swift
//  Example
//
//  Created by 秋星桥 on 1/20/25.
//

import MarkdownParser
import MarkdownView
import UIKit

final class DocumentDetailController: UIViewController {
    let scrollView = UIScrollView()
    let measureLabel = UILabel()
    private var markdownTextView: MarkdownTextView!
    private let documentContent: String
    private var streamDocument = ""

    init(document: String, title: String) {
        documentContent = document
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        scrollView.contentInset = .init(top: 16, left: 0, bottom: 64, right: 0)
        view.addSubview(scrollView)

        markdownTextView = MarkdownTextView()
        scrollView.addSubview(markdownTextView)
        markdownTextView.bindContentOffset(from: scrollView)

        measureLabel.numberOfLines = 0
        measureLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        measureLabel.textColor = .secondaryLabel

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(play),
            name: .init("Play"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetMarkdown),
            name: .init("Reset"),
            object: nil
        )

        let parser = MarkdownParser()
        let result = parser.parse(documentContent)
        let date = Date()
        markdownTextView.setMarkdownManually(.init(parserResult: result, theme: .default))
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let time = Date().timeIntervalSince(date)
        measureLabel.text = String(format: "渲染时间: %.4f ms", time * 1000)

        // Update title with metric time
        title = "\(title ?? "-")@\(Int(time * 1000))ms"

        setupNavigationBar()
    }

    private func setupNavigationBar() {
        let menu = UIMenu(children: [
            UIAction(title: "Play", image: UIImage(systemName: "play.fill"), handler: { _ in
                self.play()
            }),
            UIAction(title: "Reset", image: UIImage(systemName: "arrow.counterclockwise"), handler: { _ in
                self.resetMarkdown()
            }),
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .edit,
            primaryAction: nil,
            menu: menu
        )
    }

    @objc func play() {
        streamDocument = ""
        DispatchQueue.global().async { [self] in
            for char in documentContent {
                streamDocument.append(char)
                autoreleasepool {
                    let parser = MarkdownParser()
                    let result = parser.parse(streamDocument)
                    let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: .default)
                    DispatchQueue.main.asyncAndWait {
                        let currentOffset = scrollView.contentOffset
                        let date = Date()
                        markdownTextView.setMarkdown(content)
                        self.view.setNeedsLayout()
                        self.view.layoutIfNeeded()
                        scrollView.contentOffset = currentOffset
                        let time = Date().timeIntervalSince(date)
                        self.measureLabel.text = String(format: "渲染时间: %.4f ms", time * 1000)
                    }
                }
            }
        }
    }

    @objc func resetMarkdown() {
        streamDocument = ""
        markdownTextView.reset()
        view.setNeedsLayout()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let date = Date()

        scrollView.frame = view.bounds
        let width = view.bounds.width - 32

        let contentSize = markdownTextView.boundingSize(for: width)
        scrollView.contentSize = contentSize
        markdownTextView.frame = .init(
            x: 16,
            y: 16,
            width: width,
            height: contentSize.height
        )

        measureLabel.removeFromSuperview()
        measureLabel.frame = .init(
            x: 16,
            y: (scrollView.subviews.map(\.frame.maxY).max() ?? 0) + 16,
            width: width,
            height: 50
        )
        scrollView.addSubview(measureLabel)
        scrollView.contentSize = .init(
            width: width,
            height: measureLabel.frame.maxY + 16
        )

        let time = Date().timeIntervalSince(date)
        measureLabel.text = String(format: "布局时间: %.4f ms", time * 1000)
    }
}
