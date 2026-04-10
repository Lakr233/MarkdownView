//
//  PreprocessedContent.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/5/25.
//

import Foundation
import MarkdownParser

public extension MarkdownTextView {
    final class PreprocessedContent: @unchecked Sendable {
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
            rendered = parserResult.render(theme: theme)
            highlightMaps = parserResult.render(theme: theme)
            self.locale = locale
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

    @MainActor
    func render(theme: MarkdownTheme) -> RenderedTextContent.Map {
        var renderedContexts: [String: RenderedTextContent] = [:]
        renderMathContent(theme, &renderedContexts)
        return renderedContexts
    }
}

public extension MarkdownParser.ParseResult {
    @MainActor
    fileprivate func renderHighlighMap(_: MarkdownTheme, highlightMaps: inout [Int: CodeHighlighter.HighlightMap]) {
        var iterator: [Any] = document
        while !iterator.isEmpty {
            let node = iterator.removeFirst()
            if let node = node as? MarkdownBlockNode {
                iterator.append(contentsOf: node.children)
                switch node {
                case let .blockquote(children):
                    iterator.append(contentsOf: children)
                case let .bulletedList(_, items):
                    iterator.append(contentsOf: items.flatMap(\.children))
                case let .numberedList(_, _, items):
                    iterator.append(contentsOf: items.flatMap(\.children))
                case let .taskList(_, items):
                    iterator.append(contentsOf: items.flatMap(\.children))
                case let .codeBlock(fenceInfo, content):
                    let key = CodeHighlighter.current.key(for: content, language: fenceInfo)
                    let map = CodeHighlighter.current.highlight(key: key, content: content, language: fenceInfo)
                    highlightMaps[key] = map
                case let .paragraph(content):
                    iterator.append(contentsOf: content)
                case let .heading(_, content):
                    iterator.append(contentsOf: content)
                case let .table(_, rows):
                    iterator.append(contentsOf: rows.flatMap(\.cells).map(\.content))
                case .thematicBreak:
                    break
                }
                continue
            }
            if let node = node as? MarkdownInlineNode {
                switch node {
                // 用户说这里很乱 不要高亮了
                // case let .code(string), let .html(string):
                // let key = CodeHighlighter.current.key(for: string, language: "")
                // let map = CodeHighlighter.current.highlight(key: key, content: string, language: "")
                // highlightMaps[key] = map
                default:
                    break
                }
                continue
            }
            continue
        }
    }

    @MainActor
    func render(theme: MarkdownTheme) -> [Int: CodeHighlighter.HighlightMap] {
        var highlightMap = [Int: CodeHighlighter.HighlightMap]()
        renderHighlighMap(theme, highlightMaps: &highlightMap)
        return highlightMap
    }
}
