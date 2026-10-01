//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Foundation
import LRUCache
import OrderedCollections

#if canImport(UIKit)
    import UIKit

    public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
    import AppKit

    public typealias PlatformColor = NSColor
#endif

struct CodeHighlightRequest {
    let key: Int
    let content: String
    let language: String?
    /// The view that asked, or nil when content asked while being built.
    var requester: ObjectIdentifier? = nil
}

@MainActor
public final class CodeHighlighter {
    public typealias HighlightMap = [NSRange: PlatformColor]

    public private(set) var renderCache = LRUCache<Int, HighlightMap>(countLimit: 256)

    static let highlightDidUpdateNotification = Notification.Name("wiki.qaq.MarkdownView.CodeHighlighter.highlightDidUpdate")

    /// The keys whose highlighting finished, as a `Set<Int>` in the user info.
    ///
    /// Every view listens to one shared notification, so without this a code
    /// block finishing in one message rebuilds every other message on screen.
    /// A notification arriving without it is taken as possibly relevant.
    static let highlightedKeysUserInfoKey = "wiki.qaq.MarkdownView.CodeHighlighter.highlightedKeys"

    private let worker = HighlightWorker()
    private var pendingRequests: OrderedDictionary<Int, CodeHighlightRequest> = [:]
    private var inflightKey: Int?

    private init() {}

    public static let current = CodeHighlighter()
}

public extension CodeHighlighter {
    func key(for content: String, language: String?) -> Int {
        var hasher = Hasher()
        hasher.combine(content)
        hasher.combine(language?.lowercased() ?? "")
        return hasher.finalize()
    }

    func highlight(
        key: Int?,
        content: String,
        language: String?,
        theme _: MarkdownTheme = .default
    ) -> HighlightMap {
        let key = key ?? self.key(for: content, language: language)
        if let value = renderCache.value(forKey: key) {
            return value
        }
        let map = SyntaxHighlighter.highlight(content, language: language)
        renderCache.setValue(map, forKey: key)
        return map
    }
}

extension CodeHighlighter {
    func cachedHighlightMap(for key: Int) -> HighlightMap? {
        renderCache.value(forKey: key)
    }

    /// Queues `requests` ahead of anything already waiting.
    ///
    /// What `requester` asked for before is replaced: a streamed block asks
    /// again with every token, and its earlier prefixes would never be looked
    /// up. Every view shares this queue, so what another view asked for stays
    /// queued behind. Requests made while content was built name no view; the
    /// view showing that content asks again, so any caller replaces them.
    func scheduleHighlight(requests: [CodeHighlightRequest], requester: ObjectIdentifier? = nil) {
        var pending: OrderedDictionary<Int, CodeHighlightRequest> = [:]
        for var request in requests {
            guard request.key != inflightKey else { continue }
            guard renderCache.value(forKey: request.key) == nil else { continue }
            request.requester = requester
            pending[request.key] = request
        }
        for (key, waiting) in pendingRequests where pending[key] == nil {
            guard let owner = waiting.requester, owner != requester else { continue }
            pending[key] = waiting
        }
        pendingRequests = pending
        processNextRequestIfNeeded()
    }

    private func processNextRequestIfNeeded() {
        guard inflightKey == nil else { return }
        guard let next = pendingRequests.elements.first else { return }
        pendingRequests.removeValue(forKey: next.key)
        let request = next.value
        inflightKey = request.key
        worker.highlight(content: request.content, language: request.language) { [weak self] map in
            self?.finishHighlight(key: request.key, map: map)
        }
    }

    private func finishHighlight(key: Int, map: HighlightMap) {
        inflightKey = nil
        defer { processNextRequestIfNeeded() }
        guard renderCache.value(forKey: key) == nil else { return }
        renderCache.setValue(map, forKey: key)
        NotificationCenter.default.post(
            name: Self.highlightDidUpdateNotification,
            object: nil,
            userInfo: [Self.highlightedKeysUserInfoKey: Set([key])]
        )
    }
}

private final class HighlightWorker: Sendable {
    private let queue = DispatchQueue(label: "wiki.qaq.MarkdownView.CodeHighlighter", qos: .userInitiated)

    func highlight(
        content: String,
        language: String?,
        completion: @escaping @MainActor (CodeHighlighter.HighlightMap) -> Void
    ) {
        queue.async {
            let map = SyntaxHighlighter.highlight(content, language: language)
            Task { @MainActor in
                completion(map)
            }
        }
    }
}

public extension CodeHighlighter.HighlightMap {
    func apply(to content: String, with theme: MarkdownTheme) -> NSMutableAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CodeViewConfiguration.codeLineSpacing

        let plainTextColor = theme.colors.code
        let attributedContent: NSMutableAttributedString = .init(
            string: content,
            attributes: [
                .font: theme.fonts.code,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: plainTextColor,
            ]
        )

        let length = attributedContent.length
        for (range, color) in self {
            guard range.location >= 0, range.upperBound <= length else { continue }
            guard color != plainTextColor else { continue }
            attributedContent.addAttributes([.foregroundColor: color], range: range)
        }
        return attributedContent
    }
}
