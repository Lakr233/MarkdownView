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

private struct BacktickRun {
    let range: NSRange
    /// Index of the blank-line-separated chunk the run sits in.
    let chunk: Int
    /// A run of three or more at the start of a line opens or closes a fence,
    /// which, unlike a code span, may contain blank lines.
    let isFence: Bool
}

/// The offset just past a line's indentation and container markers: quote
/// markers, and bullets or ordinals followed by a space or the line's end.
private func containerPrefixEnd(in units: [UInt16], from start: Int) -> Int {
    func isSpaceOrEnd(_ index: Int) -> Bool {
        guard index < units.count else { return true }
        switch units[index] {
        case UInt16(UInt8(ascii: " ")), UInt16(UInt8(ascii: "\t")),
             UInt16(UInt8(ascii: "\r")), UInt16(UInt8(ascii: "\n")):
            return true
        default:
            return false
        }
    }
    let digits = UInt16(UInt8(ascii: "0")) ... UInt16(UInt8(ascii: "9"))
    var index = start
    while index < units.count {
        switch units[index] {
        case UInt16(UInt8(ascii: " ")), UInt16(UInt8(ascii: "\t")), UInt16(UInt8(ascii: ">")):
            index += 1
        case UInt16(UInt8(ascii: "-")), UInt16(UInt8(ascii: "*")), UInt16(UInt8(ascii: "+")):
            guard isSpaceOrEnd(index + 1) else { return index }
            index += 1
        case digits:
            var end = index
            while end < units.count, digits.contains(units[end]) {
                end += 1
            }
            guard end < units.count,
                  units[end] == UInt16(UInt8(ascii: ".")) || units[end] == UInt16(UInt8(ascii: ")")),
                  isSpaceOrEnd(end + 1)
            else { return index }
            index = end + 1
        default:
            return index
        }
    }
    return index
}

/// Ranges spanned by paired backtick runs, following cmark's rule that a code
/// span opener pairs with the next backtick run of the same length. A code
/// span ends at a blank line, so only a fence pairs across one.
private func backtickDelimitedRanges(in text: String) -> [NSRange] {
    guard text.utf8.contains(UInt8(ascii: "`")) else { return [] }

    // UTF-16 code units, so offsets line up with the NSRanges matched later.
    let units = Array(text.utf16)
    let backtick = UInt16(UInt8(ascii: "`"))
    var runs: [BacktickRun] = []
    var chunk = 0
    // Whether the line holds more than indentation and its container prefix
    // (`>`, `-`, `1.`), which a fence may follow and which alone leave a line
    // as blank as far as a code span is concerned.
    var lineHasContent = false
    var index = containerPrefixEnd(in: units, from: 0)
    while index < units.count {
        let unit = units[index]
        guard unit == backtick else {
            switch unit {
            case UInt16(UInt8(ascii: "\n")):
                if !lineHasContent { chunk += 1 }
                lineHasContent = false
                index = containerPrefixEnd(in: units, from: index + 1)
                continue
            case UInt16(UInt8(ascii: " ")), UInt16(UInt8(ascii: "\t")), UInt16(UInt8(ascii: "\r")):
                break
            default:
                lineHasContent = true
            }
            index += 1
            continue
        }
        var end = index + 1
        while end < units.count, units[end] == backtick {
            end += 1
        }
        runs.append(BacktickRun(
            range: NSRange(location: index, length: end - index),
            chunk: chunk,
            isFence: !lineHasContent && end - index >= 3
        ))
        lineHasContent = true
        index = end
    }

    var ranges: [NSRange] = []
    var openerIndex = 0
    while openerIndex < runs.count {
        let opener = runs[openerIndex]
        var closerIndex = openerIndex + 1
        while closerIndex < runs.count,
              runs[closerIndex].range.length != opener.range.length,
              opener.isFence || runs[closerIndex].chunk == opener.chunk
        {
            closerIndex += 1
        }
        guard closerIndex < runs.count,
              opener.isFence || runs[closerIndex].chunk == opener.chunk
        else {
            openerIndex += 1
            continue
        }
        let closer = runs[closerIndex].range
        ranges.append(NSRange(
            location: opener.range.location,
            length: closer.location + closer.length - opener.range.location
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

/// Whether a backtick run ends just before `location` with at least one of its
/// backticks unescaped — one that would still join a code span delimiter.
private func endsInUnescapedBacktick(_ text: NSString, before location: Int) -> Bool {
    let backtick = unichar(UInt8(ascii: "`"))
    let backslash = unichar(UInt8(ascii: "\\"))
    var index = location
    while index > 0, text.character(at: index - 1) == backtick {
        index -= 1
    }
    let run = location - index
    guard run > 0 else { return false }
    var backslashes = 0
    while index > 0, text.character(at: index - 1) == backslash {
        index -= 1
        backslashes += 1
    }
    // An odd number of backslashes escapes the run's first backtick only.
    return run - backslashes % 2 > 0
}

public extension MarkdownParser {
    final class MathContext {
        private let document: String
        private(set) var indexedContent: String?
        private var sourceContents: [Int: String] = [:]
        /// Placeholders inserted with a space beside them, as inserted.
        private var paddedPlaceholders: [Int: String] = [:]

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

            // The placeholder is a code span; a backtick right beside it (from
            // user code or another placeholder) would merge into its delimiter
            // run, so a space keeps the two apart. Where the placeholder ends
            // up literal, in a code block, restoring it takes the space too.
            let backtick = unichar(UInt8(ascii: "`"))
            for match in matches {
                if match.range.location > lastEnd {
                    result += nsText.substring(
                        with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    )
                }
                let matchEnd = match.range.location + match.range.length
                let followsPlaceholder = match.range.location == lastEnd && lastEnd > 0
                let spaceBefore = followsPlaceholder
                    || endsInUnescapedBacktick(nsText, before: match.range.location)
                let spaceAfter = matchEnd < nsText.length && nsText.character(at: matchEnd) == backtick
                let placeholder = register(content: match.content, source: match.source)
                let inserted = (spaceBefore ? " " : "") + placeholder + (spaceAfter ? " " : "")
                if inserted != placeholder {
                    paddedPlaceholders[contents.count - 1] = inserted
                }
                result += inserted
                lastEnd = matchEnd
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
                if let padded = paddedPlaceholders[element.key] {
                    partialResult = partialResult.replacingOccurrences(of: padded, with: source)
                }
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
