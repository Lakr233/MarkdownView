//
//  MarkdownContent.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/5/25.
//

import Foundation
import MarkdownParser

/// Parsed and pre-rendered markdown, ready for display in ``MarkdownTextView``.
///
/// Build one off the main thread for streaming scenarios, or use
/// ``init(markdown:theme:locale:)`` for one-shot rendering.
public final class MarkdownContent: @unchecked Sendable {
    private struct InlineRenderCacheKey: Hashable {
        let text: String
        let localeIdentifier: String
        let themeSignature: String
    }

    public let blocks: [MarkdownBlockNode]
    public let rendered: RenderedTextContent.Map
    public let highlightMaps: [Int: CodeHighlighter.HighlightMap]
    public let locale: Locale
    @MainActor private var inlineRenderCache: [InlineRenderCacheKey: NSAttributedString] = [:]

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
            themeSignature: theme.inlineBodyCacheSignature
        )
        if let cached = inlineRenderCache[key] {
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
        let cached = rendered.copy() as! NSAttributedString
        inlineRenderCache[key] = cached
        return cached
    }
}

public extension MarkdownTextView {
    @available(*, deprecated, renamed: "MarkdownContent")
    typealias PreprocessedContent = MarkdownContent
}

private extension MarkdownTheme {
    var inlineBodyCacheSignature: String {
        [
            fonts.body.fontName,
            String(format: "%.4f", Double(fonts.body.pointSize)),
            colors.body.cacheDescription,
        ].joined(separator: "|")
    }
}

private extension PlatformColor {
    var cacheDescription: String {
        #if canImport(UIKit)
            guard let components = cgColor.components else { return description }
        #elseif canImport(AppKit)
            guard let converted = usingColorSpace(.deviceRGB) else { return description }
            guard let components = converted.cgColor.components else { return description }
        #endif
        return components.map { String(format: "%.4f", $0) }.joined(separator: ",")
    }
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
