//
//  MarkdownTextView+Update.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import UIKit

extension MarkdownTextView {
    func updateTextExecute() {
        assert(Thread.isMainThread)

        viewProvider.lockPool()
        defer { viewProvider.unlockPool() }

        var oldViews: Set<UIView> = .init()
        for view in contextViews {
            oldViews.insert(view)
            if let view = view as? CodeView {
                viewProvider.stashCodeView(view)
                continue
            }
            if let view = view as? TableView {
                viewProvider.stashTableView(view)
                continue
            }
            assertionFailure()
        }

        viewProvider.reorderViews(matching: contextViews)
        contextViews.removeAll()

        let artifacts = TextBuilder.build(view: self, viewProvider: viewProvider)
        contentTextView.apply(document: artifacts.document, hostedViews: artifacts.subviews)
        contextViews = artifacts.subviews

        for goneView in oldViews where !artifacts.subviews.contains(goneView) {
            goneView.removeFromSuperview()
        }

        contentTextView.setNeedsLayout()
        setNeedsLayout()
    }
}
