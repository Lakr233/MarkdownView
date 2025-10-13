//
//  MarkdownTextView+Private.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import Combine
import Foundation
import UIKit

extension MarkdownTextView {
    func resetCombine() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    func setupCombine() {
        resetCombine()
        if let throttleInterval {
            contentSubject
                .throttle(for: .seconds(throttleInterval), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] content in self?.use(content) }
                .store(in: &cancellables)
        } else {
            contentSubject
                .sink { [weak self] content in self?.use(content) }
                .store(in: &cancellables)
        }
    }

    func use(_ content: PreprocessedContent) {
        assert(Thread.isMainThread)
        document = content
        // due to a bug in model gemini-flash
        // there might be a large of unknown empty whitespace inside the table
        // thus we hereby call the autoreleasepool to avoid large memory consumption
        autoreleasepool { updateTextExecute() }

        layoutIfNeeded()
    }

    func flushRenderedContent() {
        assert(Thread.isMainThread)
        viewProvider.lockPool()
        defer { viewProvider.unlockPool() }

        guard !contextViews.isEmpty else {
            contentTextView.apply(document: NSAttributedString(), hostedViews: [])
            return
        }

        for view in contextViews {
            if let codeView = view as? CodeView {
                viewProvider.stashCodeView(codeView)
            } else if let tableView = view as? TableView {
                viewProvider.stashTableView(tableView)
            } else {
                assertionFailure("Unexpected hosted view type: \(type(of: view))")
            }
            view.removeFromSuperview()
        }

        contextViews.removeAll()
        contentTextView.apply(document: NSAttributedString(), hostedViews: [])
    }
}
