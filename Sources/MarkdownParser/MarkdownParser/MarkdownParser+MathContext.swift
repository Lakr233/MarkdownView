//
//  MarkdownParser+MathContext.swift
//  MarkdownView
//
//  Created by 秋星桥 on 6/3/25.
//

import Foundation

private let mathPattern: NSRegularExpression? = {
    let patterns = [
        ###"\$\$([\s\S]*?)\$\$"###, // 块级公式 $$ ... $$
        ###"\\\\\[([\s\S]*?)\\\\\]"###, // 带转义的块级公式 \\[ ... \\]
        ###"\\\\\(([\s\S]*?)\\\\\)"###, // 带转义的行内公式 \\( ... \\)
        ###"\\\[([\s\S]*?)\\\]"###, // 单个反斜杠的块级公式 \[ ... \]
        ###"\\\(([^`\n]*?)\\\)"###, // 单个反斜杠的块级公式 \( ... \)，中间不能有 ` 和 换行
    ]
    let pattern = patterns.joined(separator: "|")
    guard let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [
            .caseInsensitive,
        ]
    ) else {
        assertionFailure("failed to create regex for math pattern")
        return nil
    }
    return regex
}()

private struct MathMatch {
    let range: NSRange
    let content: String
    let source: String
}

/// Ranges spanned by paired backtick runs, following cmark's rule that a code
/// span opener pairs with the next backtick run of the same length.
private func backtickDelimitedRanges(in text: String) -> [NSRange] {
    guard text.utf8.contains(UInt8(ascii: "`")) else { return [] }

    let backtick = unichar(UInt8(ascii: "`"))
    let nsText = text as NSString
    var runs: [NSRange] = []
    var index = 0
    while index < nsText.length {
        guard nsText.character(at: index) == backtick else {
            index += 1
            continue
        }
        var end = index + 1
        while end < nsText.length, nsText.character(at: end) == backtick {
            end += 1
        }
        runs.append(NSRange(location: index, length: end - index))
        index = end
    }

    var ranges: [NSRange] = []
    var openerIndex = 0
    while openerIndex < runs.count {
        let opener = runs[openerIndex]
        var closerIndex = openerIndex + 1
        while closerIndex < runs.count, runs[closerIndex].length != opener.length {
            closerIndex += 1
        }
        guard closerIndex < runs.count else {
            openerIndex += 1
            continue
        }
        let closer = runs[closerIndex]
        ranges.append(NSRange(
            location: opener.location,
            length: closer.location + closer.length - opener.location
        ))
        openerIndex = closerIndex + 1
    }
    return ranges
}

private func extractMathMatches(in text: String, using regex: NSRegularExpression) -> [MathMatch] {
    let nsText = text as NSString
    return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
        for rangeIndex in 1 ..< match.numberOfRanges {
            let captureRange = match.range(at: rangeIndex)
            guard captureRange.location != NSNotFound else { continue }
            return MathMatch(
                range: match.range(at: 0),
                content: nsText.substring(with: captureRange),
                source: nsText.substring(with: match.range(at: 0))
            )
        }
        return nil
    }
}

public extension MarkdownParser {
    final class MathContext {
        private let document: String
        private(set) var indexedContent: String?
        private var sourceContents: [Int: String] = [:]

        public fileprivate(set) var contents: [Int: String] = [:]

        init(preprocessText: String) {
            document = preprocessText
        }

        func process() {
            guard let regex = mathPattern else {
                assertionFailure()
                return
            }

            // Backtick-delimited regions (inline code spans and fenced blocks)
            // are literal — math markers inside them must not be replaced.
            let literalRanges = backtickDelimitedRanges(in: document)
            let matches = extractMathMatches(in: document, using: regex).filter { match in
                !literalRanges.contains { NSIntersectionRange($0, match.range).length > 0 }
            }
            if matches.isEmpty { return }

            let nsText = document as NSString
            var result = ""
            result.reserveCapacity(document.utf8.count)
            var lastEnd = 0

            for match in matches {
                if match.range.location > lastEnd {
                    result += nsText.substring(
                        with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    )
                }
                result += register(content: match.content, source: match.source)
                lastEnd = match.range.location + match.range.length
            }

            if lastEnd < nsText.length {
                result += nsText.substring(from: lastEnd)
            }

            indexedContent = result
        }

        func register(content: String, source: String? = nil) -> String {
            let identifier = contents.count
            contents[identifier] = content
            sourceContents[identifier] = source
            return MarkdownParser.replacementText(for: .math, identifier: String(identifier))
        }

        func inlineNode(forReplacementText text: String) -> MarkdownInlineNode? {
            guard !contents.isEmpty else { return nil }
            guard MarkdownParser.typeForReplacementText(text) == .math,
                  let identifier = MarkdownParser.identifierForReplacementText(text),
                  let value = Int(identifier),
                  let content = contents[value]
            else {
                return nil
            }
            return .math(
                content: content,
                replacementIdentifier: MarkdownParser.replacementText(
                    for: .math,
                    identifier: identifier
                )
            )
        }

        func restore(content: String) -> String {
            guard content.contains("md://content?type=math") else { return content }
            return contents.sorted(by: { $0.key < $1.key }).reduce(into: content) { partialResult, element in
                let placeholder = MarkdownParser.replacementText(for: .math, identifier: .init(element.key))
                let source = sourceContents[element.key] ?? element.value
                partialResult = partialResult.replacingOccurrences(of: placeholder, with: source)
            }
        }
    }
}

private let mathPatternWithinBlock: NSRegularExpression? = {
    let patterns = [
        ###"\\\(([^\r\n]+?)\\\)"###, // 行内公式 \(...\)
        ###"(?<![\d$])\$(?=\S)([^\r\n$]+?)(?<=\S)\$(?!\d)"###, // 行内公式 $...$，排除货币金额
    ]
    let pattern = patterns.joined(separator: "|")
    guard let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [
            .caseInsensitive,
        ]
    ) else {
        assertionFailure("failed to create regex for math pattern")
        return nil
    }
    return regex
}()

private func textMayContainInlineMath(_ text: String) -> Bool {
    var previous: UInt8 = 0
    for byte in text.utf8 {
        if byte == UInt8(ascii: "$") { return true }
        if previous == UInt8(ascii: "\\"), byte == UInt8(ascii: "(") { return true }
        previous = byte
    }
    return false
}

extension MarkdownParser {
    func finalizeMathBlocks(_ nodes: [MarkdownBlockNode], mathContext: MathContext) -> [MarkdownBlockNode] {
        let inlineFinalized = nodes.rewrite { node in
            finalizeInlineMath(node, mathContext: mathContext)
        }
        guard !mathContext.contents.isEmpty else { return inlineFinalized }
        return inlineFinalized.rewrite { node in
            guard case let .codeBlock(language, content) = node else {
                return [node]
            }
            return [.codeBlock(fenceInfo: language, content: mathContext.restore(content: content))]
        }
    }

    private func finalizeInlineMath(_ node: MarkdownInlineNode, mathContext: MathContext) -> [MarkdownInlineNode] {
        switch node {
        case let .text(text):
            processInlineMath(in: text, mathContext: mathContext)
        case let .code(content):
            if let mathNode = mathContext.inlineNode(forReplacementText: content) {
                [mathNode]
            } else {
                [.code(mathContext.restore(content: content))]
            }
        default:
            [node]
        }
    }

    private func processInlineMath(in text: String, mathContext: MathContext) -> [MarkdownInlineNode] {
        guard textMayContainInlineMath(text) else { return [.text(text)] }
        guard let regex = mathPatternWithinBlock else { return [.text(text)] }
        let matches = extractMathMatches(in: text, using: regex)
        if matches.isEmpty { return [.text(text)] }

        let nsText = text as NSString
        var result: [MarkdownInlineNode] = []
        var lastEnd = 0

        for match in matches {
            if match.range.location > lastEnd {
                let beforeText = nsText.substring(
                    with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
                )
                if !beforeText.isEmpty { result.append(.text(beforeText)) }
            }

            result.append(
                .math(
                    content: match.content,
                    replacementIdentifier: mathContext.register(content: match.content)
                )
            )

            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            let remainingText = nsText.substring(from: lastEnd)
            if !remainingText.isEmpty {
                result.append(.text(remainingText))
            }
        }

        return result
    }
}
