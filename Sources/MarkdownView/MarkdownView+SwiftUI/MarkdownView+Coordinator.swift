//
//  MarkdownView+Coordinator.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import Foundation
import MarkdownParser
import SwiftUI

@MainActor
final class MarkdownViewCoordinator {
    static let throttleInterval: TimeInterval = 1 / 20

    var lastText: String = ""
    var lastContent: MarkdownContent?
    var lastTheme: MarkdownTheme = .default
    var lastParseResult: MarkdownParser.ParseResult?

    var width: CGFloat = 0
    var heightBinding: Binding<CGFloat>?

    private var pendingText: String?
    private var pendingTheme: MarkdownTheme?
    private var lastApplyDate: Date = .distantPast
    private var scheduledTask: Task<Void, Never>?

    var targetText: String { pendingText ?? lastText }
    var targetTheme: MarkdownTheme { pendingTheme ?? lastTheme }

    func setTextThrottled(_ text: String, theme: MarkdownTheme, on view: MarkdownTextView) {
        let now = Date()
        if scheduledTask == nil, now.timeIntervalSince(lastApplyDate) >= Self.throttleInterval {
            apply(text: text, theme: theme, to: view)
            return
        }
        pendingText = text
        pendingTheme = theme
        guard scheduledTask == nil else { return }
        let delay = max(0, lastApplyDate.addingTimeInterval(Self.throttleInterval).timeIntervalSince(now))
        scheduledTask = Task { @MainActor [weak self, weak view] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            scheduledTask = nil
            guard let view, let text = pendingText else { return }
            apply(text: text, theme: pendingTheme ?? lastTheme, to: view)
        }
    }

    func cancelScheduledApply() {
        scheduledTask?.cancel()
        scheduledTask = nil
        pendingText = nil
        pendingTheme = nil
    }

    func updateMeasuredHeight(for view: MarkdownTextView) {
        guard width.isFinite, width > 0 else { return }
        guard let heightBinding else { return }
        let height = measuredHeight(for: view, width: width)
        guard abs(height - heightBinding.wrappedValue) > 0.5 else { return }
        DispatchQueue.main.async {
            heightBinding.wrappedValue = height
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, for view: MarkdownTextView) -> CGSize? {
        let proposedWidth = proposal.width ?? width
        let fallbackWidth = view.bounds.width
        let fittingWidth: CGFloat
        if proposedWidth.isFinite, proposedWidth > 0 {
            fittingWidth = proposedWidth
        } else {
            fittingWidth = fallbackWidth
        }
        guard fittingWidth.isFinite, fittingWidth > 0 else { return nil }
        width = fittingWidth
        let height = measuredHeight(for: view, width: fittingWidth)
        updateMeasuredHeight(height)
        return CGSize(width: fittingWidth, height: height)
    }

    private func measuredHeight(for view: MarkdownTextView, width: CGFloat) -> CGFloat {
        let size = view.boundingSize(for: width)
        return ceil(size.height)
    }

    private func updateMeasuredHeight(_ height: CGFloat) {
        guard let heightBinding else { return }
        guard abs(height - heightBinding.wrappedValue) > 0.5 else { return }
        DispatchQueue.main.async {
            heightBinding.wrappedValue = height
        }
    }

    private func apply(text: String, theme: MarkdownTheme, to view: MarkdownTextView) {
        cancelScheduledApply()
        let result: MarkdownParser.ParseResult
        if lastText == text, let cached = lastParseResult {
            result = cached
        } else {
            result = MarkdownParser().parse(text)
        }
        let content = MarkdownContent(parserResult: result, theme: theme)
        lastText = text
        lastParseResult = result
        lastContent = nil
        view.theme = theme
        view.setContentImmediately(content)
        view.invalidateIntrinsicContentSize()
        lastTheme = theme
        lastApplyDate = Date()
        updateMeasuredHeight(for: view)
    }
}
