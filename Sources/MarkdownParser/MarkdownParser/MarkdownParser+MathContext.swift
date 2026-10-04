//
//  MarkdownParser+MathContext.swift
//  MarkdownView
//
//  Created by 秋星桥 on 6/3/25.
//

import Foundation

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
private func backtickDelimitedRanges(in units: [UInt16]) -> [NSRange] {
    let backtick = UInt16(UInt8(ascii: "`"))
    guard units.contains(backtick) else { return [] }

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
                if !lineHasContent {
                    chunk += 1
                }
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
            isFence: !lineHasContent && end - index >= 3,
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
            length: closer.location + closer.length - opener.range.location,
        ))
        openerIndex = closerIndex + 1
    }
    return ranges
}

private func mathMatches(_ matches: [MathDelimiterScanner.Match], in text: inout UTF16Slicer) -> [MathMatch] {
    matches.map { match in
        let source = text.string(match.range)
        return MathMatch(range: match.range, content: text.string(match.contentRange), source: source)
    }
}

/// Slices a string at UTF-16 offsets, walking from the last offset asked for
/// rather than from the start, so ascending offsets cost one pass in total.
///
/// Slices are taken by scalar, never rounded to a character boundary: a
/// delimiter may be followed by a combining mark.
private struct UTF16Slicer {
    let text: String
    private var index: String.Index
    private var offset = 0

    init(_ text: String) {
        self.text = text
        index = text.startIndex
    }

    mutating func index(at target: Int) -> String.Index {
        index = text.utf16.index(index, offsetBy: target - offset)
        offset = target
        return index
    }

    mutating func substring(_ range: NSRange) -> Substring {
        let start = index(at: range.location)
        let end = index(at: range.location + range.length)
        return Substring(text.unicodeScalars[start ..< end])
    }

    mutating func string(_ range: NSRange) -> String {
        String(substring(range))
    }
}

/// Whether `text` holds what every delimited math match starts with: `$$`,
/// `\[` or `\(` (which `\\[` and `\\(` contain).
///
/// Most answers have none, and this byte scan is far cheaper than the regex.
private func documentMayContainDelimitedMath(_ text: String) -> Bool {
    var previous: UInt8 = 0
    for byte in text.utf8 {
        switch byte {
        case UInt8(ascii: "$") where previous == UInt8(ascii: "$"):
            return true
        case UInt8(ascii: "[") where previous == UInt8(ascii: "\\"),
             UInt8(ascii: "(") where previous == UInt8(ascii: "\\"):
            return true
        default:
            break
        }
        previous = byte
    }
    return false
}

/// Whether a backtick run ends just before `location` with at least one of its
/// backticks unescaped — one that would still join a code span delimiter.
private func endsInUnescapedBacktick(_ units: [UInt16], before location: Int) -> Bool {
    let backtick = UInt16(UInt8(ascii: "`"))
    let backslash = UInt16(UInt8(ascii: "\\"))
    var index = location
    while index > 0, units[index - 1] == backtick {
        index -= 1
    }
    let run = location - index
    guard run > 0 else { return false }
    var backslashes = 0
    while index > 0, units[index - 1] == backslash {
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
            guard documentMayContainDelimitedMath(document) else { return }
            // UTF-16 code units, so offsets line up with NSString ranges.
            let units = Array(document.utf16)
            var scanned = MathDelimiterScanner.delimitedMath(in: units)
            if scanned.isEmpty {
                return
            }
            // Backtick-delimited regions (inline code spans and fenced blocks)
            // are literal — math markers inside them must not be replaced.
            let literalRanges = backtickDelimitedRanges(in: units)
            scanned.removeAll { match in
                literalRanges.contains { NSIntersectionRange($0, match.range).length > 0 }
            }
            if scanned.isEmpty {
                return
            }

            var slicer = UTF16Slicer(document)
            let matches = mathMatches(scanned, in: &slicer)
            var result = ""
            result.reserveCapacity(document.utf8.count)
            var lastEnd = 0

            // The placeholder is a code span; a backtick right beside it (from
            // user code or another placeholder) would merge into its delimiter
            // run, so a space keeps the two apart. Where the placeholder ends
            // up literal, in a code block, restoring it takes the space too.
            let backtick = UInt16(UInt8(ascii: "`"))
            for match in matches {
                if match.range.location > lastEnd {
                    result += slicer.substring(
                        NSRange(location: lastEnd, length: match.range.location - lastEnd),
                    )
                }
                let matchEnd = match.range.location + match.range.length
                let followsPlaceholder = match.range.location == lastEnd && lastEnd > 0
                let spaceBefore = followsPlaceholder
                    || endsInUnescapedBacktick(units, before: match.range.location)
                let spaceAfter = matchEnd < units.count && units[matchEnd] == backtick
                let placeholder = register(content: match.content, source: match.source)
                let inserted = (spaceBefore ? " " : "") + placeholder + (spaceAfter ? " " : "")
                if inserted != placeholder {
                    paddedPlaceholders[contents.count - 1] = inserted
                }
                result += inserted
                lastEnd = matchEnd
            }

            if lastEnd < units.count {
                result += slicer.substring(NSRange(location: lastEnd, length: units.count - lastEnd))
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
            guard !contents.isEmpty, text.utf8Contains("md://content?") else { return nil }
            guard let identifier = Self.placeholderIdentifier(in: text)
                ?? Self.parsedMathIdentifier(in: text),
                let value = Int(identifier),
                let content = contents[value]
            else {
                return nil
            }
            return .math(
                content: content,
                replacementIdentifier: MarkdownParser.replacementText(
                    for: .math,
                    identifier: identifier,
                ),
            )
        }

        /// The identifier of a math placeholder exactly as `register` writes
        /// it, without the URL parsing that anything else needs.
        private static func placeholderIdentifier(in text: String) -> String? {
            let prefix = "md://content?type=math&identifier=".utf8
            let utf8 = text.utf8
            guard utf8.count > prefix.count, utf8.starts(with: prefix) else { return nil }
            let digits = utf8.dropFirst(prefix.count)
            guard digits.allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }) else { return nil }
            return String(digits)
        }

        private static func parsedMathIdentifier(in text: String) -> String? {
            guard MarkdownParser.typeForReplacementText(text) == .math else { return nil }
            return MarkdownParser.identifierForReplacementText(text)
        }

        func restore(content: String) -> String {
            guard content.utf8Contains("md://content?type=math") else { return content }
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

private func textMayContainInlineMath(_ text: String) -> Bool {
    var previous: UInt8 = 0
    for byte in text.utf8 {
        if byte == UInt8(ascii: "$") {
            return true
        }
        if previous == UInt8(ascii: "\\"), byte == UInt8(ascii: "(") {
            return true
        }
        previous = byte
    }
    return false
}

extension MarkdownParser {
    func finalizeMathBlocks(_ nodes: [MarkdownBlockNode], mathContext: MathContext) -> [MarkdownBlockNode] {
        // Without placeholders, only a text node with math changes, and most
        // documents have none: finding that out is cheaper than rebuilding.
        if mathContext.contents.isEmpty, !nodes.containsText(where: textMayContainInlineMath) {
            return nodes
        }
        let inlineFinalized = nodes.rewrite { node in
            finalizeInlineMath(node, mathContext: mathContext)
        }
        guard !mathContext.contents.isEmpty,
              inlineFinalized.containsCodeBlock(where: { $0.utf8Contains("md://content?type=math") })
        else { return inlineFinalized }
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
        let units = Array(text.utf16)
        let scanned = MathDelimiterScanner.inlineMath(in: units)
        if scanned.isEmpty {
            return [.text(text)]
        }

        var slicer = UTF16Slicer(text)
        let matches = mathMatches(scanned, in: &slicer)
        var result: [MarkdownInlineNode] = []
        var lastEnd = 0

        for match in matches {
            if match.range.location > lastEnd {
                let beforeText = slicer.string(
                    NSRange(location: lastEnd, length: match.range.location - lastEnd),
                )
                if !beforeText.isEmpty {
                    result.append(.text(beforeText))
                }
            }

            result.append(
                .math(
                    content: match.content,
                    replacementIdentifier: mathContext.register(content: match.content),
                ),
            )

            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < units.count {
            let remainingText = slicer.string(NSRange(location: lastEnd, length: units.count - lastEnd))
            if !remainingText.isEmpty {
                result.append(.text(remainingText))
            }
        }

        return result
    }
}
