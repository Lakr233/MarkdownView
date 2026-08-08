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
                if let keys = notification.userInfo?[CodeHighlighter.highlightedKeysUserInfoKey]
                    as? Set<Int>,
                    renderedHighlightKeys.isDisjoint(with: keys)
                {
                    return
                }
                use(content)
            }
            .store(in: &cancellables)
    }

    func setupCombine() {
        resetCombine()
        if let throttleInterval {
            contentSubject
                .dropFirst()
                .throttle(for: .seconds(throttleInterval), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] content in self?.use(content) }
                .store(in: &cancellables)
        } else {
            contentSubject
                .dropFirst()
                .sink { [weak self] content in self?.use(content) }
                .store(in: &cancellables)
        }
    }

    func use(_ content: MarkdownContent) {
        assert(Thread.isMainThread)
        self.content = content
        // due to a bug in model gemini-flash
        // there might be a large of unknown empty whitespace inside the table
        // thus we hereby call the autoreleasepool to avoid large memory consumption
        autoreleasepool { updateTextExecute() }

        #if canImport(UIKit)
            layoutIfNeeded()
        #elseif canImport(AppKit)
            layoutSubtreeIfNeeded()
        #endif
    }
}
