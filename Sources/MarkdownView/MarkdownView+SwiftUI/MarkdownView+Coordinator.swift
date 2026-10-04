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
    var lastIsStreaming = false
    var lastContent: MarkdownContent?
    var lastTheme: MarkdownTheme = .default
    /// The text `lastParseResult` was parsed from: `lastText`, with its
    /// unfinished end closed while streaming.
    var lastParsedText: String = ""
    var lastParseResult: MarkdownParser.ParseResult?

    var width: CGFloat = 0

    private var pendingText: String?
    private var pendingTheme: MarkdownTheme?
    private var pendingIsStreaming: Bool?
    private var lastApplyDate: Date = .distantPast
    private var scheduledTask: Task<Void, Never>?

    var targetText: String {
        pendingText ?? lastText
    }

    var targetTheme: MarkdownTheme {
        pendingTheme ?? lastTheme
    }

    var targetIsStreaming: Bool {
        pendingIsStreaming ?? lastIsStreaming
    }

    func setTextThrottled(
        _ text: String,
        theme: MarkdownTheme,
        isStreaming: Bool = false,
        on view: MarkdownTextView,
    ) {
        let now = Date()
        if scheduledTask == nil, now.timeIntervalSince(lastApplyDate) >= Self.throttleInterval {
            apply(text: text, theme: theme, isStreaming: isStreaming, to: view)
            return
        }
        pendingText = text
        pendingTheme = theme
        pendingIsStreaming = isStreaming
        guard scheduledTask == nil else { return }
        let delay = max(0, lastApplyDate.addingTimeInterval(Self.throttleInterval).timeIntervalSince(now))
        scheduledTask = Task { @MainActor [weak self, weak view] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            scheduledTask = nil
            guard let view, let text = pendingText else { return }
            apply(
                text: text,
                theme: pendingTheme ?? lastTheme,
                isStreaming: pendingIsStreaming ?? lastIsStreaming,
                to: view,
            )
        }
    }

    func cancelScheduledApply() {
        scheduledTask?.cancel()
        scheduledTask = nil
        pendingText = nil
        pendingTheme = nil
        pendingIsStreaming = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, for view: MarkdownTextView) -> CGSize? {
        // A zero-width proposal asks for the minimum width. Text can wrap to
        // any width, so answer with zero — reporting the current layout width
        // here pins the hosting window's minimum width and makes it
        // impossible to shrink the window.
        if proposal.width == 0 {
            return .zero
        }
        // SwiftUI also probes with infinite and nil width proposals while
        // negotiating the flexible frame. Those probes must be answered with
        // the last concrete width — falling back to the view's current bounds
        // reports a stale width (and its height) after a resize, which the
        // host then applies, leaving the text laid out for the old width.
        let fittingWidth: CGFloat
        if let proposed = proposal.width, proposed.isFinite, proposed > 0 {
            fittingWidth = proposed
            width = proposed
        } else if width > 0 {
            fittingWidth = width
        } else if view.bounds.width > 0 {
            fittingWidth = view.bounds.width
        } else {
            return nil
        }
        let height = measuredHeight(for: view, width: fittingWidth)
        return CGSize(width: fittingWidth, height: height)
    }

    private func measuredHeight(for view: MarkdownTextView, width: CGFloat) -> CGFloat {
        let size = view.boundingSize(for: width)
        return ceil(size.height)
    }

    private func apply(text: String, theme: MarkdownTheme, isStreaming: Bool, to view: MarkdownTextView) {
        cancelScheduledApply()
        // While streaming, the unfinished end is closed before parsing. The
        // cache is keyed on the text that is parsed, so a stream that ends
        // without new text parses again without the repair — unless the
        // repair had nothing to do, and the view already shows the result.
        let parsedText = isStreaming
            ? MarkdownParser.StreamingTail(closing: text).applied(to: text)
            : text
        let cached = lastParsedText == parsedText ? lastParseResult : nil
        lastText = text
        lastIsStreaming = isStreaming
        if cached != nil, lastContent == nil, theme == lastTheme, lastApplyDate != .distantPast {
            return
        }
        let result = cached ?? MarkdownParser().parse(parsedText)
        let content = MarkdownContent(parserResult: result, theme: theme)
        lastParsedText = parsedText
        lastParseResult = result
        lastContent = nil
        // A deferred (throttled) apply happens outside a SwiftUI update
        // cycle; the view invalidating its intrinsic size on every rebuild is
        // what prompts SwiftUI to re-query sizeThatFits(_:).
        if let streamView = view as? MarkdownStreamView,
           streamView.isStreaming,
           lastApplyDate != .distantPast,
           theme == lastTheme
        {
            // More of a stream already on screen: the view paces it and fades
            // the new text in.
            streamView.setContent(content)
        } else {
            view.setContentImmediately(content, theme: theme)
        }
        lastTheme = theme
        lastApplyDate = Date()
    }
}
