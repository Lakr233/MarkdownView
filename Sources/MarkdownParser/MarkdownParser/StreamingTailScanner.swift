//
//  StreamingTailScanner.swift
//  MarkdownView
//

import Foundation

/// Works out ``MarkdownParser/StreamingTail`` for a document's bytes.
///
/// One pass over the lines finds where the last block starts and whether the
/// end sits inside fenced code or `$$` math; a second pass reads only the last
/// block's inlines. The rules follow cmark-gfm closely enough to agree with it
/// on what is open, and lean towards changing nothing where they do not: a
/// wrong guess shows up as text snapping into a different shape, which is
/// what the repair exists to avoid.
struct StreamingTailScanner {
    let bytes: UnsafeBufferPointer<UInt8>

    private var count: Int {
        bytes.count
    }

    private var unchanged: (keep: Int, suffix: String) {
        (count, "")
    }

    func repair() -> (keep: Int, suffix: String) {
        guard count > 0 else { return unchanged }
        let blocks = scanBlocks()
        let endsWithNewline = bytes[count - 1] == .newline

        if let fence = blocks.openFence {
            return repairInsideFence(fence, lastLine: blocks.lastLine, endsWithNewline: endsWithNewline)
        }
        // The math pre-pass pairs `$$` across the whole document, so an odd
        // count leaves the end inside a formula. Leave it alone.
        guard blocks.doubleDollarCount % 2 == 0 else { return unchanged }
        var tailLines = blocks.tailLines
        guard !tailLines.isEmpty else { return unchanged }
        guard !blocks.tailIsIndentedCode else { return unchanged }

        if let table = repairTableHeader(tailLines, endsWithNewline: endsWithNewline) {
            return table
        }

        // A line ended by a newline is finished: what it left open is
        // most likely literal.
        guard !endsWithNewline else { return unchanged }

        var keep = count
        if let last = tailLines.last, isMarkerOnly(last) {
            keep = last.lowerBound
            tailLines.removeLast()
            guard !tailLines.isEmpty else { return (keep, "") }
        }

        // The inlines of the last leaf block: from the last line that starts
        // a block of its own, or the block's first line.
        var scopeStart = tailLines[0].lowerBound
        for line in tailLines.reversed() where startsBlock(line) {
            scopeStart = line.lowerBound
            break
        }
        // A line held back above leaves its newline in the kept text.
        var scopeEnd = keep
        while scopeEnd > scopeStart, bytes[scopeEnd - 1].isWhitespace {
            scopeEnd -= 1
        }
        let lastLineStart = tailLines[tailLines.count - 1].lowerBound
        let inline = InlineScanner(
            bytes: bytes,
            scope: scopeStart ..< scopeEnd,
            lastLineStart: lastLineStart,
            isTableRow: isPipeRow(tailLines[tailLines.count - 1]),
        ).repair()
        if let inline {
            return inline
        }
        return (keep, "")
    }

    // MARK: - Blocks

    private struct Fence {
        let character: UInt8
        let length: Int
        let lineStart: Int
    }

    private struct BlockScan {
        var openFence: Fence?
        var doubleDollarCount = 0
        /// The lines since the last blank line or closed fence.
        var tailLines: [Range<Int>] = []
        var tailIsIndentedCode = false
        var lastLine: Range<Int> = 0 ..< 0
    }

    private func scanBlocks() -> BlockScan {
        var scan = BlockScan()
        var inList = false
        var lineStart = 0
        while lineStart < count {
            var lineEnd = lineStart
            while lineEnd < count, bytes[lineEnd] != .newline {
                lineEnd += 1
            }
            let line = lineStart ..< lineEnd
            scan.lastLine = line
            lineStart = lineEnd + 1

            if let fence = scan.openFence {
                if isClosingFence(line, of: fence) {
                    scan.openFence = nil
                    scan.tailLines.removeAll(keepingCapacity: true)
                }
                continue
            }
            let content = contentStart(line)
            if isBlank(line) {
                scan.tailLines.removeAll(keepingCapacity: true)
                continue
            }
            let isListItem = startsListItem(line)
            if isListItem {
                inList = true
            } else if leadingColumns(line) < 2, scan.tailLines.isEmpty {
                inList = false
            }
            if inList || leadingColumns(line) < 4, let fence = openingFence(line, content: content) {
                scan.openFence = fence
                scan.tailLines.removeAll(keepingCapacity: true)
                continue
            }
            if scan.tailLines.isEmpty {
                scan.tailIsIndentedCode = !inList && leadingColumns(line) >= 4
            }
            scan.doubleDollarCount += doubleDollars(in: line)
            scan.tailLines.append(line)
        }
        return scan
    }

    private func repairInsideFence(
        _ fence: Fence,
        lastLine: Range<Int>,
        endsWithNewline: Bool,
    ) -> (keep: Int, suffix: String) {
        // cmark runs an unclosed fence to the end already. Hold back the
        // opening line until its info string is whole, and a partial closing
        // run, so it never shows as a line of code.
        guard !endsWithNewline else { return unchanged }
        if fence.lineStart == lastLine.lowerBound {
            return (lastLine.lowerBound, "")
        }
        let content = contentStart(lastLine)
        let run = runLength(of: fence.character, from: content, before: lastLine.upperBound)
        if run > 0, content + run == lastLine.upperBound {
            return (lastLine.lowerBound, "")
        }
        return unchanged
    }

    private func openingFence(_ line: Range<Int>, content: Int) -> Fence? {
        guard content < line.upperBound else { return nil }
        let character = bytes[content]
        guard character == .backtick || character == .tilde else { return nil }
        let run = runLength(of: character, from: content, before: line.upperBound)
        guard run >= 3 else { return nil }
        if character == .backtick {
            // A backtick fence's info string holds no backticks: ```a``` is a
            // code span.
            for index in content + run ..< line.upperBound where bytes[index] == .backtick {
                return nil
            }
        }
        return Fence(character: character, length: run, lineStart: line.lowerBound)
    }

    private func isClosingFence(_ line: Range<Int>, of fence: Fence) -> Bool {
        let content = contentStart(line)
        let run = runLength(of: fence.character, from: content, before: line.upperBound)
        return run >= fence.length && isBlank(content + run ..< line.upperBound)
    }

    // MARK: - Tables

    /// A pipe header row whose delimiter row is missing or partial gets one.
    private func repairTableHeader(
        _ tailLines: [Range<Int>],
        endsWithNewline: Bool,
    ) -> (keep: Int, suffix: String)? {
        let headerIndex = endsWithNewline ? tailLines.count - 1 : tailLines.count - 2
        guard headerIndex >= 0 else { return nil }
        let header = tailLines[headerIndex]
        // The header starts the block, or follows a heading.
        guard headerIndex == 0 || (headerIndex == 1 && isATXHeading(tailLines[0])) else { return nil }
        guard isPipeRow(header), !isDelimiterRow(header) else { return nil }
        let row = "|" + String(repeating: " --- |", count: cellCount(header))
        if endsWithNewline {
            return (count, row)
        }
        let last = tailLines[tailLines.count - 1]
        guard isDelimiterRow(last) else { return nil }
        return (last.lowerBound, row)
    }

    private func isPipeRow(_ line: Range<Int>) -> Bool {
        var index = line.lowerBound
        while index < line.upperBound, bytes[index] == .space {
            index += 1
        }
        return index < line.upperBound && bytes[index] == .pipe && cellCount(line) > 0
    }

    private func cellCount(_ line: Range<Int>) -> Int {
        var pipes = 0
        var index = line.lowerBound
        while index < line.upperBound {
            if bytes[index] == .backslash {
                index += 2
                continue
            }
            if bytes[index] == .pipe {
                pipes += 1
            }
            index += 1
        }
        var end = line.upperBound
        while end > line.lowerBound, bytes[end - 1].isSpaceOrTab || bytes[end - 1] == .carriageReturn {
            end -= 1
        }
        let hasTrailingPipe = end > line.lowerBound && bytes[end - 1] == .pipe
        return hasTrailingPipe ? pipes - 1 : pipes
    }

    /// Only the characters of a delimiter row, so far.
    private func isDelimiterRow(_ line: Range<Int>) -> Bool {
        var sawDash = false
        for index in line {
            switch bytes[index] {
            case .dash: sawDash = true
            case .pipe, .colon, .space, .tab, .carriageReturn: continue
            default: return false
            }
        }
        return sawDash || bytes[line].contains(.pipe)
    }

    // MARK: - Lines

    private func isBlank(_ range: Range<Int>) -> Bool {
        bytes[range].allSatisfy { $0.isSpaceOrTab || $0 == .carriageReturn }
    }

    private func leadingColumns(_ line: Range<Int>) -> Int {
        var columns = 0
        for index in line {
            switch bytes[index] {
            case .space: columns += 1
            case .tab: columns += 4 - columns % 4
            default: return columns
            }
        }
        return columns
    }

    /// Past indentation and container markers (`>`, `-`, `1.`).
    private func contentStart(_ line: Range<Int>) -> Int {
        var index = line.lowerBound
        while index < line.upperBound {
            let byte = bytes[index]
            if byte.isSpaceOrTab || byte == .greaterThan {
                index += 1
                continue
            }
            if let next = listMarkerEnd(at: index, in: line) {
                index = next
                continue
            }
            break
        }
        return index
    }

    /// Where the content after a list marker at `index` starts.
    private func listMarkerEnd(at index: Int, in line: Range<Int>) -> Int? {
        let byte = bytes[index]
        if byte == .dash || byte == .plus || byte == .asterisk {
            guard index + 1 < line.upperBound, bytes[index + 1].isSpaceOrTab else { return nil }
            return index + 2
        }
        guard byte.isDigit else { return nil }
        var end = index
        while end < line.upperBound, bytes[end].isDigit, end - index < 9 {
            end += 1
        }
        guard end + 1 < line.upperBound,
              bytes[end] == .period || bytes[end] == .closeParen,
              bytes[end + 1].isSpaceOrTab
        else { return nil }
        return end + 2
    }

    private func startsListItem(_ line: Range<Int>) -> Bool {
        var index = line.lowerBound
        while index < line.upperBound, bytes[index].isSpaceOrTab || bytes[index] == .greaterThan {
            index += 1
        }
        return index < line.upperBound && listMarkerEnd(at: index, in: line) != nil
    }

    private func isATXHeading(_ line: Range<Int>) -> Bool {
        var index = line.lowerBound
        while index < line.upperBound, bytes[index] == .space {
            index += 1
        }
        let run = runLength(of: .hash, from: index, before: line.upperBound)
        guard (1 ... 6).contains(run) else { return false }
        return index + run == line.upperBound || bytes[index + run].isSpaceOrTab
    }

    /// Whether the line begins a block of its own: a list item, a quote, a
    /// heading or a table row.
    private func startsBlock(_ line: Range<Int>) -> Bool {
        if contentStart(line) != line.lowerBound + leadingSpaces(line) {
            return true
        }
        return isATXHeading(line) || isPipeRow(line)
    }

    private func leadingSpaces(_ line: Range<Int>) -> Int {
        var index = line.lowerBound
        while index < line.upperBound, bytes[index].isSpaceOrTab {
            index += 1
        }
        return index - line.lowerBound
    }

    /// A line of nothing but block markers — `-`, `1.`, `#`, `>`, `---`,
    /// `==`, `**`, a lone `|`, `- [ ]` — would show as an empty item, an
    /// empty heading, or turn the line above into a setext heading, then snap.
    private func isMarkerOnly(_ line: Range<Int>) -> Bool {
        guard !isBlank(line) else { return false }
        var index = line.lowerBound
        var sawMarker = false
        while index < line.upperBound {
            let byte = bytes[index]
            if byte.isSpaceOrTab || byte == .carriageReturn {
                index += 1
                continue
            }
            if Self.markerBytes.contains(byte) {
                sawMarker = true
                index += 1
                continue
            }
            // The `x` of a task box.
            if byte == .lowercaseX || byte == .uppercaseX, index > line.lowerBound, bytes[index - 1] == .openBracket {
                index += 1
                continue
            }
            if byte.isDigit {
                // `1.` starts an ordered item. A bare number only at the
                // start of the line, where it may still become one.
                var end = index
                while end < line.upperBound, bytes[end].isDigit {
                    end += 1
                }
                guard end - index <= 9 else { return false }
                if end == line.upperBound {
                    guard index == line.lowerBound + leadingSpaces(line) else { return false }
                } else if bytes[end] != .period, bytes[end] != .closeParen {
                    return false
                }
                sawMarker = true
                index = min(end + 1, line.upperBound)
                continue
            }
            return false
        }
        return sawMarker
    }

    private static let markerBytes: Set<UInt8> = Set("#-=*+_>|`~:[]".utf8)

    private func doubleDollars(in line: Range<Int>) -> Int {
        var found = 0
        var index = line.lowerBound
        while index + 1 < line.upperBound {
            if bytes[index] == .backslash {
                index += 2
            } else if bytes[index] == .dollar, bytes[index + 1] == .dollar {
                found += 1
                index += 2
            } else {
                index += 1
            }
        }
        return found
    }

    private func runLength(of byte: UInt8, from start: Int, before end: Int) -> Int {
        var index = start
        while index < end, bytes[index] == byte {
            index += 1
        }
        return index - start
    }
}

// MARK: - Inlines

/// Reads the inlines of the last leaf block and closes what is left open.
private struct InlineScanner {
    let bytes: UnsafeBufferPointer<UInt8>
    let scope: Range<Int>
    /// Only openers on the last line are closed: one left open across a line
    /// break is more likely literal than a long emphasis.
    let lastLineStart: Int
    let isTableRow: Bool

    fileprivate enum Opener {
        case delimiter(character: UInt8, count: Int, position: Int)
        case bracket(position: Int, isImage: Bool)
    }

    /// The repair, or `nil` when the block needs none.
    func repair() -> (keep: Int, suffix: String)? {
        var end = scope.upperBound
        while end > scope.lowerBound, bytes[end - 1].isSpaceOrTab || bytes[end - 1] == .carriageReturn {
            end -= 1
        }
        var stack: [Opener] = []
        var keep = end
        var closer = ""
        var index = scope.lowerBound

        scan: while index < end {
            let byte = bytes[index]
            switch byte {
            case .pipe where isTableRow:
                stack.removeAll()
                index += 1

            case .backslash:
                guard index + 1 < end else {
                    keep = index
                    break scan
                }
                var next = index + 1
                if bytes[next] == .backslash, next + 1 < end,
                   bytes[next + 1] == .openParen || bytes[next + 1] == .openBracket
                {
                    next += 1
                }
                let opened = bytes[next]
                if opened == .openParen || opened == .openBracket {
                    // `\(` and `\[` open math; its source is not markdown.
                    let closing: UInt8 = opened == .openParen ? .closeParen : .closeBracket
                    guard let close = find(.backslash, then: closing, from: next + 1, before: end) else {
                        break scan
                    }
                    index = close + 2
                    continue
                }
                index += 2

            case .dollar:
                if index + 1 < end, bytes[index + 1] == .dollar {
                    guard let close = find(.dollar, then: .dollar, from: index + 2, before: end) else {
                        break scan
                    }
                    index = close + 2
                    continue
                }
                guard opensInlineMath(at: index, end: end) else {
                    index += 1
                    continue
                }
                guard let close = inlineMathClose(after: index, end: end) else {
                    break scan
                }
                index = close + 1

            case .backtick:
                let run = runLength(of: byte, from: index, before: end)
                if let close = findRun(of: byte, length: run, from: index + run, before: end) {
                    index = close + run
                    continue
                }
                if index + run == end, index >= lastLineStart {
                    keep = index
                    break scan
                }
                // An unmatched run is a code span being written only when it
                // is on the last line and code follows it at once.
                guard index >= lastLineStart, !bytes[index + run].isWhitespace else {
                    index += run
                    continue
                }
                closer = String(repeating: "`", count: run)
                break scan

            case .asterisk, .underscore, .tilde:
                let run = runLength(of: byte, from: index, before: end)
                let start = index
                index += run
                let before = characterClass(before: start)
                guard index < end else {
                    // A run at the very end opens nothing yet: hold it back,
                    // unless it closes what came before it.
                    if before != .whitespace, closeDelimiter(byte, run: run, in: &stack) {
                        continue
                    }
                    if before != .other, start >= lastLineStart {
                        keep = start
                        break scan
                    }
                    continue
                }
                if byte == .tilde, run != 2 {
                    continue
                }
                let after = characterClass(at: index)
                let flanking = Flanking(before: before, after: after)
                var canOpen = flanking.isLeft
                var canClose = flanking.isRight
                if byte == .underscore {
                    canOpen = flanking.isLeft && (!flanking.isRight || before == .punctuation)
                    canClose = flanking.isRight && (!flanking.isLeft || after == .punctuation)
                }
                if canClose, closeDelimiter(byte, run: run, in: &stack) {
                    continue
                }
                guard canOpen, start >= lastLineStart, speculates(after: index, run: start ..< index) else {
                    continue
                }
                stack.append(.delimiter(character: byte, count: min(run, 3), position: start))

            case .exclamation where index + 1 < end && bytes[index + 1] == .openBracket:
                stack.append(.bracket(position: index, isImage: true))
                index += 2

            case .openBracket:
                stack.append(.bracket(position: index, isImage: false))
                index += 1

            case .closeBracket:
                guard let opener = stack.lastIndex(where: \.isBracket),
                      case let .bracket(start, isImage) = stack[opener]
                else {
                    index += 1
                    continue
                }
                if isImage, index + 1 == end, start >= lastLineStart {
                    // `![alt]` may still get its source.
                    keep = start
                    break scan
                }
                guard index + 1 < end, bytes[index + 1] == .openParen else {
                    stack.remove(at: opener)
                    index += 1
                    continue
                }
                // An inline link: its text is done with.
                stack.removeSubrange(opener...)
                if let close = destinationEnd(from: index + 1, before: end) {
                    index = close + 1
                    continue
                }
                if isImage, start >= lastLineStart {
                    // Half an image shows as nothing until it is whole.
                    keep = start
                    break scan
                }
                closer = destinationCloser(from: index + 1, before: end)
                break scan

            case .lessThan:
                if heldBackTag(at: index, end: end) {
                    keep = index
                    break scan
                }
                index += 1

            case .ampersand:
                var entityEnd = index + 1
                if entityEnd < end, bytes[entityEnd] == .hash {
                    entityEnd += 1
                }
                while entityEnd < end, bytes[entityEnd].isASCIIAlphanumeric {
                    entityEnd += 1
                }
                // `&amp` still being written, not the `&T` of `AT&T`.
                let startsWord = characterClass(before: index) != .other
                if entityEnd == end, entityEnd - index > 1, entityEnd - index <= 32, index >= lastLineStart, startsWord {
                    keep = index
                    break scan
                }
                index = max(entityEnd, index + 1)

            default:
                index += 1
            }
        }

        let live = stack.filter { opener in
            switch opener {
            case let .delimiter(_, _, position): position < keep && position >= lastLineStart
            case let .bracket(position, isImage): isImage && position < keep && position >= lastLineStart
            }
        }
        let result = close(live, keep: keep, suffix: closer)
        guard result.keep < scope.upperBound || !result.suffix.isEmpty else { return nil }
        if result.suffix.isEmpty, result.keep == end {
            // Only trailing whitespace would go: keep it.
            return nil
        }
        return result
    }

    /// Closes the open stack innermost first. An opener with nothing after
    /// it is dropped, and an unfinished image is dropped whole.
    private func close(_ stack: [Opener], keep: Int, suffix: String) -> (keep: Int, suffix: String) {
        var keep = keep
        var suffix = suffix
        for opener in stack.reversed() {
            switch opener {
            case let .delimiter(character, count, position):
                var contentEnd = keep
                while contentEnd > position + count, bytes[contentEnd - 1].isSpaceOrTab {
                    contentEnd -= 1
                }
                if suffix.isEmpty {
                    if contentEnd <= position + count {
                        keep = position
                        continue
                    }
                    keep = contentEnd
                }
                suffix += String(repeating: String(UnicodeScalar(character)), count: count)
            case let .bracket(position, _):
                keep = position
                suffix = ""
            }
        }
        while suffix.isEmpty, keep > scope.lowerBound, bytes[keep - 1].isSpaceOrTab {
            keep -= 1
        }
        return (keep, suffix)
    }

    /// Closes the nearest opener of `character` with a run of `run`. Openers
    /// above it are dropped, as cmark drops them.
    @discardableResult
    private func closeDelimiter(_ character: UInt8, run: Int, in stack: inout [Opener]) -> Bool {
        guard let opener = stack.lastIndex(where: { $0.isDelimiter(character) }),
              case let .delimiter(_, count, position) = stack[opener]
        else { return false }
        if run < count {
            stack.removeSubrange((opener + 1)...)
            stack[opener] = .delimiter(character: character, count: count - run, position: position)
        } else {
            stack.removeSubrange(opener...)
        }
        return true
    }

    /// Whether an opener is worth closing: one followed by a word. `*.txt`
    /// and `2*3` stay literal.
    private func speculates(after index: Int, run: Range<Int>) -> Bool {
        let next = bytes[index]
        if next < 0x80 {
            guard next.isASCIIAlphanumeric || Self.speculativeFollowers.contains(next) else { return false }
            if next.isASCIIAlphanumeric, run.lowerBound > scope.lowerBound, bytes[run.lowerBound - 1].isASCIIAlphanumeric {
                // Between two ASCII words — `2*3`, `x**2`, `snake_case` — it
                // is an operator or part of a name far more often.
                return false
            }
            return true
        }
        return characterClass(at: index) == .other
    }

    private static let speculativeFollowers: Set<UInt8> = Set("`[(\"'".utf8)

    // MARK: Spans

    private func find(_ first: UInt8, then second: UInt8, from start: Int, before end: Int) -> Int? {
        var index = start
        while index + 1 < end {
            if bytes[index] == first, bytes[index + 1] == second {
                return index
            }
            index += 1
        }
        return nil
    }

    private func runLength(of byte: UInt8, from start: Int, before end: Int) -> Int {
        var index = start
        while index < end, bytes[index] == byte {
            index += 1
        }
        return index - start
    }

    /// A run of exactly `length` `byte`s at or after `start`.
    private func findRun(of byte: UInt8, length: Int, from start: Int, before end: Int) -> Int? {
        var index = start
        while index < end {
            guard bytes[index] == byte else {
                index += 1
                continue
            }
            let run = runLength(of: byte, from: index, before: end)
            if run == length {
                return index
            }
            index += run
        }
        return nil
    }

    /// Whether `$` here opens inline math the way the math pass reads it:
    /// not money, so neither a digit before it nor a digit or space after.
    private func opensInlineMath(at index: Int, end: Int) -> Bool {
        guard index + 1 < end else { return false }
        let next = bytes[index + 1]
        if next.isDigit || next.isWhitespace {
            return false
        }
        return index == scope.lowerBound || !bytes[index - 1].isDigit
    }

    private func inlineMathClose(after open: Int, end: Int) -> Int? {
        var index = open + 2
        while index < end {
            let byte = bytes[index]
            if byte == .newline {
                return nil
            }
            if byte == .dollar, !bytes[index - 1].isWhitespace,
               index + 1 == end || !bytes[index + 1].isDigit
            {
                return index
            }
            index += 1
        }
        return nil
    }

    /// The `)` ending the link destination opened at `open`, if it arrived.
    private func destinationEnd(from open: Int, before end: Int) -> Int? {
        var depth = 0
        var index = open
        while index < end {
            switch bytes[index] {
            case .backslash:
                index += 1
            case .openParen:
                depth += 1
            case .closeParen:
                depth -= 1
                if depth == 0 {
                    return index
                }
            default:
                break
            }
            index += 1
        }
        return nil
    }

    /// What closes a destination cut off after `open`: the title's quote, an
    /// angle bracket, and the parentheses still open.
    private func destinationCloser(from open: Int, before end: Int) -> String {
        var depth = 0
        var quotes = 0
        var angled = open + 1 < end && bytes[open + 1] == .lessThan
        var index = open
        while index < end {
            switch bytes[index] {
            case .backslash: index += 1
            case .openParen where quotes % 2 == 0: depth += 1
            case .closeParen where quotes % 2 == 0: depth -= 1
            case .quote: quotes += 1
            case .greaterThan: angled = false
            default: break
            }
            index += 1
        }
        var closer = ""
        if quotes % 2 == 1 {
            closer += "\""
        }
        if angled {
            closer += ">"
        }
        return closer + String(repeating: ")", count: max(depth, 1))
    }

    /// A tag or autolink still being written at the end of the line: `<di`,
    /// `</sp`, `<a href="x`, `<https://exa`. `a < b` and `if a <b then` stay.
    private func heldBackTag(at index: Int, end: Int) -> Bool {
        guard index >= lastLineStart, index + 1 < end else { return index + 1 == end && index >= lastLineStart }
        var cursor = index + 1
        if bytes[cursor] == .slash {
            cursor += 1
        }
        let nameStart = cursor
        while cursor < end, bytes[cursor].isASCIIAlphanumeric || bytes[cursor] == .dash {
            cursor += 1
        }
        guard cursor > nameStart, bytes[nameStart].isASCIILetter else { return false }
        if cursor == end {
            return true
        }
        var rest = cursor
        var sawEquals = false
        var sawSpace = false
        while rest < end {
            switch bytes[rest] {
            case .greaterThan: return false
            case .equals: sawEquals = true
            case .space, .tab: sawSpace = true
            default: break
            }
            rest += 1
        }
        if bytes[cursor] == .colon {
            // An autolink: a scheme and no spaces yet.
            return !sawSpace
        }
        return sawEquals && bytes[cursor].isSpaceOrTab
    }

    // MARK: Characters

    private enum CharacterClass {
        case whitespace
        case punctuation
        case other
    }

    /// cmark's left- and right-flanking rules.
    private struct Flanking {
        let isLeft: Bool
        let isRight: Bool

        init(before: CharacterClass, after: CharacterClass) {
            isLeft = after != .whitespace
                && (after != .punctuation || before != .other)
            isRight = before != .whitespace
                && (before != .punctuation || after != .other)
        }
    }

    /// The class of the character before `index`; the scope's start counts as
    /// whitespace.
    private func characterClass(before index: Int) -> CharacterClass {
        guard index > scope.lowerBound else { return .whitespace }
        var start = index - 1
        while start > scope.lowerBound, bytes[start] & 0xC0 == 0x80 {
            start -= 1
        }
        return characterClass(at: start)
    }

    private func characterClass(at index: Int) -> CharacterClass {
        let byte = bytes[index]
        if byte < 0x80 {
            if byte.isWhitespace {
                return .whitespace
            }
            return byte.isASCIIAlphanumeric ? .other : .punctuation
        }
        guard let scalar = scalar(at: index) else { return .other }
        if scalar.properties.isWhitespace {
            return .whitespace
        }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return .punctuation
        default:
            return .other
        }
    }

    private func scalar(at index: Int) -> Unicode.Scalar? {
        let lead = bytes[index]
        let length = lead >= 0xF0 ? 4 : lead >= 0xE0 ? 3 : lead >= 0xC0 ? 2 : 1
        guard index + length <= bytes.count else { return nil }
        var iterator = bytes[index ..< index + length].makeIterator()
        var decoder = UTF8()
        guard case let .scalarValue(scalar) = decoder.decode(&iterator) else { return nil }
        return scalar
    }
}

private extension InlineScanner.Opener {
    var isBracket: Bool {
        if case .bracket = self {
            true
        } else {
            false
        }
    }

    func isDelimiter(_ byte: UInt8) -> Bool {
        if case let .delimiter(character, _, _) = self {
            character == byte
        } else {
            false
        }
    }
}

private extension UInt8 {
    static let tab = UInt8(ascii: "\t")
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let space = UInt8(ascii: " ")
    static let exclamation = UInt8(ascii: "!")
    static let quote = UInt8(ascii: "\"")
    static let hash = UInt8(ascii: "#")
    static let dollar = UInt8(ascii: "$")
    static let ampersand = UInt8(ascii: "&")
    static let openParen = UInt8(ascii: "(")
    static let closeParen = UInt8(ascii: ")")
    static let asterisk = UInt8(ascii: "*")
    static let plus = UInt8(ascii: "+")
    static let dash = UInt8(ascii: "-")
    static let period = UInt8(ascii: ".")
    static let slash = UInt8(ascii: "/")
    static let colon = UInt8(ascii: ":")
    static let lessThan = UInt8(ascii: "<")
    static let equals = UInt8(ascii: "=")
    static let greaterThan = UInt8(ascii: ">")
    static let openBracket = UInt8(ascii: "[")
    static let backslash = UInt8(ascii: "\\")
    static let closeBracket = UInt8(ascii: "]")
    static let underscore = UInt8(ascii: "_")
    static let backtick = UInt8(ascii: "`")
    static let pipe = UInt8(ascii: "|")
    static let tilde = UInt8(ascii: "~")
    static let lowercaseX = UInt8(ascii: "x")
    static let uppercaseX = UInt8(ascii: "X")

    var isSpaceOrTab: Bool {
        self == .space || self == .tab
    }

    var isWhitespace: Bool {
        isSpaceOrTab || self == .newline || self == .carriageReturn
    }

    var isDigit: Bool {
        self >= UInt8(ascii: "0") && self <= UInt8(ascii: "9")
    }

    var isASCIILetter: Bool {
        (self | 0x20) >= UInt8(ascii: "a") && (self | 0x20) <= UInt8(ascii: "z")
    }

    var isASCIIAlphanumeric: Bool {
        isDigit || isASCIILetter
    }
}
