//
//  MarkdownContent.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/5/25.
//

import Foundation
import LRUCache
import MarkdownParser

/// Parsed and pre-rendered markdown, ready for display in ``MarkdownTextView``.
///
/// Build one off the main thread for streaming scenarios, or use
/// ``init(markdown:theme:locale:)`` for one-shot rendering.
public final class MarkdownContent: @unchecked Sendable {
    /// What a rendered piece of body text depends on.
    ///
    /// The font and colour are held as themselves rather than as a formatted
    /// description of them. Describing them cost more than every other part of
    /// rendering the text put together, and it also made two colours that
    /// happen to resolve alike today share one entry — which hands a caller
    /// asking for a dynamic colour a copy frozen in the current appearance.
    /// Fonts and colours are immutable once handed to a theme, so a key holding
    /// them can cross the actor boundary the cache requires.
    private struct InlineRenderCacheKey: Hashable, @unchecked Sendable {
        let text: String
        let localeIdentifier: String
        let font: PlatformFont
        let color: PlatformColor
    }

    /// Rendered body text, shared by every content rather than owned by one.
    ///
    /// Streaming builds a fresh ``MarkdownContent`` for each token, so a cache
    /// living on the instance never saw a second lookup in the one situation it
    /// exists for. Shared, a stream re-renders only the paragraph that grew.
    /// Bounded by entry count, and cleared under memory pressure by `LRUCache`.
    @MainActor private static let inlineRenderCache =
        LRUCache<InlineRenderCacheKey, NSAttributedString>(countLimit: 4096)

    public let blocks: [MarkdownBlockNode]
    public let rendered: RenderedTextContent.Map
    public let highlightMaps: [Int: CodeHighlighter.HighlightMap]
    public let locale: Locale

    public init(
        blocks: [MarkdownBlockNode],
        rendered: RenderedTextContent.Map,
        highlightMaps: [Int: CodeHighlighter.HighlightMap],
        locale: Locale = .autoupdatingCurrent
    ) {
        self.blocks = blocks
        self.rendered = rendered
        self.highlightMaps = highlightMaps
        self.locale = locale
    }

    @MainActor
    public init(
        parserResult: MarkdownParser.ParseResult,
        theme: MarkdownTheme,
        locale: Locale = .autoupdatingCurrent
    ) {
        blocks = parserResult.document
        rendered = parserResult.renderedContent(theme: theme)
        highlightMaps = parserResult.highlightMaps(theme: theme)
        self.locale = locale
    }

    /// Parses markdown text and pre-renders it in one step.
    @MainActor
    public convenience init(
        markdown: String,
        theme: MarkdownTheme = .default,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.init(
            parserResult: MarkdownParser().parse(markdown),
            theme: theme,
            locale: locale
        )
    }

    public init() {
        blocks = .init()
        rendered = .init()
        highlightMaps = .init()
        locale = .autoupdatingCurrent
    }

    @MainActor
    func cachedBodyText(_ text: String, theme: MarkdownTheme) -> NSAttributedString {
        let key = InlineRenderCacheKey(
            text: text,
            localeIdentifier: locale.identifier,
            font: theme.fonts.body,
            color: theme.colors.body
        )
        if let cached = Self.inlineRenderCache.value(forKey: key) {
            return cached
        }

        let rendered = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
            ]
        )
        MarkdownContentLocale.applyLanguageAttributes(
            to: rendered,
            fallbackLocale: locale
        )
        // Resolve the fallback font here, once per distinct piece of text,
        // rather than leaving it to the pass over the finished document.
        // The body font covers no CJK and no emoji, so that pass was asking
        // CoreText for a substitute for the same runs on every rebuild — a
        // third of the cost of a streaming update.
        rendered.fixAttributes(in: NSRange(location: 0, length: rendered.length))
        let cached = rendered.copy() as! NSAttributedString
        Self.inlineRenderCache.setValue(cached, forKey: key)
        return cached
    }
}

public extension MarkdownTextView {
    @available(*, deprecated, renamed: "MarkdownContent")
    typealias PreprocessedContent = MarkdownContent
}

public extension MarkdownParser.ParseResult {
    @MainActor
    fileprivate func renderMathContent(_ theme: MarkdownTheme, _ renderedContexts: inout [String: RenderedTextContent]) {
        for (key, value) in mathContext {
            var image = MathRenderer.renderToImage(
                latex: value,
                fontSize: theme.fonts.body.pointSize,
                textColor: theme.colors.body
            )
            #if canImport(UIKit)
                image = image?.withRenderingMode(.alwaysTemplate)
            #endif
            let renderedContext = RenderedTextContent(
                image: image,
                text: value
            )
            let replacementText = MarkdownParser.replacementText(for: .math, identifier: .init(key))
            renderedContexts[replacementText] = renderedContext
        }
    }

    /// Renders math expressions into images keyed by their replacement text.
    @MainActor
    func renderedContent(theme: MarkdownTheme) -> RenderedTextContent.Map {
        var renderedContexts: [String: RenderedTextContent] = [:]
        renderMathContent(theme, &renderedContexts)
        return renderedContexts
    }

    @available(*, deprecated, renamed: "renderedContent(theme:)")
    @MainActor
    func render(theme: MarkdownTheme) -> RenderedTextContent.Map {
        renderedContent(theme: theme)
    }
}

public extension MarkdownParser.ParseResult {
    @MainActor
    fileprivate func renderHighlighMap(_: MarkdownTheme, highlightMaps: inout [Int: CodeHighlighter.HighlightMap]) {
        var pendingRequests: [CodeHighlightRequest] = []
        var queue: [MarkdownBlockNode] = document
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1
            queue.append(contentsOf: node.children)
            switch node {
            case let .codeBlock(fenceInfo, content):
                let key = CodeHighlighter.current.key(for: content, language: fenceInfo)
                if let map = CodeHighlighter.current.cachedHighlightMap(for: key) {
                    highlightMaps[key] = map
                } else {
                    pendingRequests.append(.init(key: key, content: content, language: fenceInfo))
                }
            default:
                break
            }
        }
        if !pendingRequests.isEmpty {
            CodeHighlighter.current.scheduleHighlight(requests: pendingRequests)
        }
    }

    /// Collects cached highlight maps for code blocks and schedules
    /// asynchronous highlighting for the rest.
    @MainActor
    func highlightMaps(theme: MarkdownTheme) -> [Int: CodeHighlighter.HighlightMap] {
        var highlightMap = [Int: CodeHighlighter.HighlightMap]()
        renderHighlighMap(theme, highlightMaps: &highlightMap)
        return highlightMap
    }

    @available(*, deprecated, renamed: "highlightMaps(theme:)")
    @MainActor
    func render(theme: MarkdownTheme) -> [Int: CodeHighlighter.HighlightMap] {
        highlightMaps(theme: theme)
    }
}
