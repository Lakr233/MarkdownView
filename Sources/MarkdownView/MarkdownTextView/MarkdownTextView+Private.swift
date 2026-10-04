//
//  MarkdownTextView+Private.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import Combine
import Foundation
import Litext

extension MarkdownTextView {
    func resetCombine() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        NotificationCenter.default
            .publisher(for: CodeHighlighter.highlightDidUpdateNotification)
            .sink { [weak self] notification in
                guard let self else { return }
                // One shared notification reaches every view on screen, so a
                // code block finishing in one message used to rebuild all of
                // them. A notification that does not name the blocks it
                // finished still means a rebuild — it could be any of them.
                guard let keys = notification.userInfo?[CodeHighlighter.highlightedKeysUserInfoKey]
                    as? Set<Int>
                else {
                    // A highlight colours text it already laid out.
                    use(content, resizes: false)
                    return
                }
                guard !renderedHighlightKeys.isDisjoint(with: keys) else { return }
                applyFinishedHighlights(keys)
            }
            .store(in: &cancellables)
    }

    /// Colours the code blocks whose highlighting just finished, and nothing
    /// else.
    ///
    /// Colour never changes a block's size, so the document and its layout
    /// stay exactly as they are; only the code views showing `keys` take
    /// their maps. A map the highlighter no longer holds falls back to a
    /// rebuild, which asks for it again.
    func applyFinishedHighlights(_ keys: Set<Int>) {
        var needsRebuild = false
        for case let codeView as CodeView in contextViews {
            guard let key = codeView.highlightKey,
                  keys.contains(key),
                  codeView.highlightedKey != key
            else { continue }
            guard let map = CodeHighlighter.current.cachedHighlightMap(for: key) else {
                needsRebuild = true
                continue
            }
            codeView.setContent(codeView.content, highlightMap: map, highlightKey: key)
        }
        if needsRebuild {
            use(content, resizes: false)
        }
    }

    func setupCombine() {
        resetCombine()
        if let throttleInterval {
            contentSubject
                .dropFirst()
                .throttle(for: .seconds(throttleInterval), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] content in self?.deliverStreamedContent(content) }
                .store(in: &cancellables)
        } else {
            contentSubject
                .dropFirst()
                .sink { [weak self] content in self?.deliverStreamedContent(content) }
                .store(in: &cancellables)
        }
    }

    /// Rebuilds the throttle for a new interval.
    ///
    /// The old throttle may be holding content it has not delivered yet, and
    /// the new subscription drops the subject's current value, so that
    /// content is shown now rather than lost.
    func resubscribeKeepingPendingContent() {
        setupCombine()
        let pending = contentSubject.value
        guard pending !== content else { return }
        use(pending)
    }

    /// Hands the current handlers to the code and table views already on
    /// screen; layout does the same for views placed later.
    func syncContextViewHandlers() {
        for view in contextViews {
            if let codeView = view as? CodeView {
                codeView.previewAction = codePreviewHandler
                codeView.actionProvider = codeBlockActionProvider
            } else if let tableView = view as? TableView {
                tableView.linkHandler = linkHandler
            }
        }
    }

    /// Rebuilds the document for `content`.
    ///
    /// `resizes` is false for a rebuild that only recolours what is on
    /// screen, which leaves the height alone and so need not send SwiftUI back
    /// through `sizeThatFits(_:)`. `streamed` is true for content that came
    /// through ``setContent(_:)``; see ``applyDocument(_:newContextViews:animated:)``.
    func use(_ content: MarkdownContent, resizes: Bool = true, streamed: Bool = false) {
        assert(Thread.isMainThread)
        rebuildIsStreamed = streamed
        defer { rebuildIsStreamed = false }
        self.content = content
        // due to a bug in model gemini-flash
        // there might be a large of unknown empty whitespace inside the table
        // thus we hereby call the autoreleasepool to avoid large memory consumption
        autoreleasepool { updateTextExecute() }
        // The height changes with the document. Auto Layout hosts and the
        // SwiftUI representable both learn of it only through this.
        if resizes {
            invalidateIntrinsicContentSize()
        }

        #if canImport(UIKit)
            layoutIfNeeded()
        #elseif canImport(AppKit)
            layoutSubtreeIfNeeded()
        #endif
    }
}
