import Foundation

/// Colours code with a single lexical pass.
///
/// This is deliberately approximate. It knows each language's comments,
/// strings, numbers and keywords, and guesses the rest from the shape of a
/// word: a capitalised word is a type, the word after `func` or `def` is a
/// declaration, a word before `:` in JSON or YAML is a key. It has no grammar,
/// so it gets some code wrong; it aims for code that reads well, quickly, not
/// for the precision of a parser. A block's ranges are measured in UTF-16 units,
/// as `NSAttributedString` counts them.
enum SyntaxHighlighter {
    static func highlight(_ content: String, language info: String?) -> CodeHighlighter.HighlightMap {
        guard let language = SyntaxLanguage.named(info), !content.isEmpty else { return [:] }
        let units = Array(content.utf16)
        return units.withUnsafeBufferPointer { buffer in
            var scanner = SyntaxScanner(units: buffer, language: language)
            scanner.scan()
            return scanner.map
        }
    }
}

private struct SyntaxScanner {
    let units: UnsafeBufferPointer<UInt16>
    let language: SyntaxLanguage
    private let lineComments: [[UInt16]]
    private let blockOpen: [UInt16]
    private let blockClose: [UInt16]

    private(set) var map: CodeHighlighter.HighlightMap = [:]
    private var index = 0
    /// Only spaces since the last line break.
    private var atLineStart = true
    /// The last word was a keyword such as `func` that names what follows.
    private var expectsDeclaredName = false

    init(units: UnsafeBufferPointer<UInt16>, language: SyntaxLanguage) {
        self.units = units
        self.language = language
        lineComments = language.lineComments.map { Array($0.utf16) }
        blockOpen = language.blockComment.map { Array($0.open.utf16) } ?? []
        blockClose = language.blockComment.map { Array($0.close.utf16) } ?? []
    }

    mutating func scan() {
        switch language.mode {
        case .code: scanCode()
        case .markup: scanMarkup()
        case .diff: scanDiff()
        }
    }

    // MARK: - Code

    private mutating func scanCode() {
        let count = units.count
        while index < count {
            let unit = units[index]
            if unit.isLineBreak {
                atLineStart = true
                index += 1
                continue
            }
            if unit.isSpace {
                index += 1
                continue
            }
            let start = index
            let lineStart = atLineStart
            atLineStart = false

            if unit.startsIdentifier {
                scanWord()
                continue
            }
            expectsDeclaredName = false

            if language.variables, unit == .dollar, let end = variableEnd(from: start) {
                mark(start, end, .variable)
            } else if !blockOpen.isEmpty, matches(blockOpen, at: start) {
                let end = find(blockClose, from: start + blockOpen.count).map { $0 + blockClose.count } ?? count
                mark(start, end, .comment)
            } else if startsLineComment(at: start) {
                mark(start, lineEnd(from: start), .comment)
            } else if language.tripleQuotes, unit == .doubleQuote || unit == .singleQuote, opensTripleQuote(at: start) {
                let delimiter = [unit, unit, unit]
                let end = find(delimiter, from: start + 3).map { $0 + 3 } ?? count
                mark(start, end, .string)
            } else if language.quotes.contains(unit), let end = stringEnd(from: start, quote: unit) {
                mark(start, end, isKey(before: end) ? .attribute : .string)
            } else if unit.isDigit {
                mark(start, numberEnd(from: start), .number)
            } else if language.directives, unit == .hash, let end = directiveEnd(from: start, atLineStart: lineStart) {
                mark(start, end, .meta)
            } else if language.annotations, unit == .at, start + 1 < count, units[start + 1].startsIdentifier {
                mark(start, identifierEnd(from: start + 1), .meta)
            } else {
                index = start + 1
            }
        }
    }

    private mutating func scanWord() {
        let start = index
        let end = identifierEnd(from: start)
        index = end
        let word = SyntaxWord(units, from: start, to: end, foldsCase: language.foldsCase)

        if let word, language.keywords.contains(word) {
            mark(start, end, .keyword)
            expectsDeclaredName = language.declarations.contains(word)
            return
        }
        if expectsDeclaredName {
            expectsDeclaredName = false
            mark(start, end, .number)
            return
        }
        if let word, language.literals.contains(word) {
            mark(start, end, .keyword)
        } else if let word, language.types.contains(word) {
            mark(start, end, .type)
        } else if isKey(before: end) {
            mark(start, end, .attribute)
        } else if language.capitalizedTypes, units[start].isUppercase {
            mark(start, end, .type)
        }
    }

    private func identifierEnd(from start: Int) -> Int {
        var end = start + 1
        while end < units.count {
            let unit = units[end]
            if unit.continuesIdentifier {
                end += 1
            } else if language.hyphenatedWords, unit == .hyphen,
                      end + 1 < units.count, units[end + 1].continuesIdentifier
            {
                end += 2
            } else {
                break
            }
        }
        return end
    }

    /// Whether the token ending at `end` is followed by the language's key
    /// separator: `"name":` in JSON, `name:` in YAML, `name =` in TOML.
    private func isKey(before end: Int) -> Bool {
        guard let separator = language.keySeparator else { return false }
        var cursor = end
        while cursor < units.count, units[cursor].isSpace {
            cursor += 1
        }
        guard cursor < units.count, units[cursor] == separator else { return false }
        // `a::b` is a path and `a == b` a comparison, not keys.
        return cursor + 1 >= units.count || units[cursor + 1] != separator
    }

    private func startsLineComment(at start: Int) -> Bool {
        for prefix in lineComments where matches(prefix, at: start) {
            // `#` inside a word is not a comment: `a#b`, a URL fragment, `$#`.
            if prefix == [.hash], start > 0, units[start - 1].continuesIdentifier || units[start - 1] == .dollar {
                continue
            }
            return true
        }
        return false
    }

    private func opensTripleQuote(at start: Int) -> Bool {
        start + 2 < units.count && units[start + 1] == units[start] && units[start + 2] == units[start]
    }

    /// The end of the string opened at `start`, or nil when it does not close
    /// where it must, so a stray apostrophe is not taken for a string.
    private func stringEnd(from start: Int, quote: UInt16) -> Int? {
        let count = units.count
        if quote == .singleQuote, language.singleQuoteIsCharacter {
            return characterLiteralEnd(from: start)
        }
        let multiline = language.multilineQuotes.contains(quote)
        var cursor = start + 1
        while cursor < count {
            let unit = units[cursor]
            if unit == .backslash {
                cursor += 2
                continue
            }
            if unit == quote {
                return cursor + 1
            }
            if unit.isLineBreak, !multiline {
                return nil
            }
            cursor += 1
        }
        // A multiline string still being streamed runs to the end.
        return multiline ? count : nil
    }

    /// `'a'`, `'\n'`, `'\u{1F600}'`; anything else, like the lifetime in
    /// `&'a str`, is not a literal.
    private func characterLiteralEnd(from start: Int) -> Int? {
        let count = units.count
        guard start + 2 < count else { return nil }
        if units[start + 1] != .backslash {
            return units[start + 2] == .singleQuote ? start + 3 : nil
        }
        var cursor = start + 2
        while cursor < min(count, start + 12) {
            if units[cursor] == .singleQuote {
                return cursor + 1
            }
            if units[cursor].isLineBreak {
                return nil
            }
            cursor += 1
        }
        return nil
    }

    /// `42`, `0x1F`, `3.14`, `1_000`, `2.5e3`, `10px`; a range like `1..5`
    /// stops at the dots.
    private func numberEnd(from start: Int) -> Int {
        let count = units.count
        var end = start + 1
        while end < count {
            let unit = units[end]
            if unit.continuesIdentifier, unit < 0x80 {
                end += 1
            } else if unit == .period, end + 1 < count, units[end + 1].isDigit {
                end += 1
            } else if unit == .plus || unit == .hyphen, (units[end - 1] | 0x20) == 0x65,
                      end + 1 < count, units[end + 1].isDigit, !isHexadecimal(from: start)
            {
                end += 1
            } else {
                break
            }
        }
        return end
    }

    private func isHexadecimal(from start: Int) -> Bool {
        start + 1 < units.count && units[start] == 0x30 && (units[start + 1] | 0x20) == 0x78
    }

    /// `#include`, `#if`, `#available`, and Rust's `#[derive(Debug)]`.
    private func directiveEnd(from start: Int, atLineStart: Bool) -> Int? {
        let count = units.count
        var cursor = start + 1
        if cursor < count, units[cursor] == .exclamation {
            cursor += 1
        }
        if cursor < count, units[cursor] == 0x5B { // [
            let line = lineEnd(from: cursor)
            var depth = 0
            while cursor < line {
                if units[cursor] == 0x5B {
                    depth += 1
                }
                if units[cursor] == 0x5D {
                    depth -= 1
                }
                cursor += 1
                if depth == 0 {
                    return cursor
                }
            }
            return line
        }
        // C allows `#  define`; only at the start of a line is that a directive.
        if atLineStart {
            while cursor < count, units[cursor].isSpace {
                cursor += 1
            }
        }
        guard cursor < count, units[cursor].isLetter else { return nil }
        return identifierEnd(from: cursor)
    }

    /// `$name`, `${name}`, `$1`, `$@`; nil for a lone `$`.
    private func variableEnd(from start: Int) -> Int? {
        let count = units.count
        guard start + 1 < count else { return nil }
        let next = units[start + 1]
        if next == .openBrace {
            let line = lineEnd(from: start)
            var cursor = start + 2
            while cursor < line {
                if units[cursor] == .closeBrace {
                    return cursor + 1
                }
                cursor += 1
            }
            return nil
        }
        if next.startsIdentifier, next < 0x80 {
            return identifierEnd(from: start + 1)
        }
        if next.isDigit || next == .at || next == .hash || next == .question || next == .exclamation
            || next == .dollar || next == 0x2A // *
        {
            return start + 2
        }
        return nil
    }

    // MARK: - Markup

    private mutating func scanMarkup() {
        let count = units.count
        var insideTag = false
        while index < count {
            let start = index
            let unit = units[start]

            if matches(Self.markupCommentOpen, at: start) {
                let close = find(Self.markupCommentClose, from: start + 4)
                let end = close.map { $0 + Self.markupCommentClose.count } ?? count
                mark(start, end, .comment)
                continue
            }
            if !insideTag {
                if unit == .lessThan, start + 1 < count {
                    var cursor = start + 1
                    let next = units[cursor]
                    if next == .question || next == .exclamation {
                        // `<?xml …?>`, `<!DOCTYPE html>`
                        let end = find([.greaterThan], from: cursor).map { $0 + 1 } ?? lineEnd(from: cursor)
                        mark(start, end, .meta)
                        continue
                    }
                    if next == .slash {
                        cursor += 1
                    }
                    if cursor < count, units[cursor].startsIdentifier {
                        let end = markupNameEnd(from: cursor)
                        mark(cursor, end, .keyword)
                        insideTag = true
                        index = end
                        continue
                    }
                }
                index = start + 1
                continue
            }

            if unit == .greaterThan {
                insideTag = false
                index = start + 1
            } else if unit == .doubleQuote || unit == .singleQuote {
                let end = find([unit], from: start + 1).map { $0 + 1 } ?? count
                mark(start, end, .string)
            } else if unit.startsIdentifier {
                mark(start, markupNameEnd(from: start), .attribute)
            } else {
                index = start + 1
            }
        }
    }

    private static let markupCommentOpen: [UInt16] = Array("<!--".utf16)
    private static let markupCommentClose: [UInt16] = Array("-->".utf16)

    /// Tag and attribute names: `svg:path`, `data-id`, `v-on:click`, `@click`.
    private func markupNameEnd(from start: Int) -> Int {
        var end = start + 1
        while end < units.count {
            let unit = units[end]
            guard unit.continuesIdentifier || unit == .hyphen || unit == .colon || unit == .period else { break }
            end += 1
        }
        return end
    }

    // MARK: - Diff

    private mutating func scanDiff() {
        let count = units.count
        while index < count {
            let start = index
            let end = lineEnd(from: start)
            switch units[start] {
            case .plus: mark(start, end, .comment)
            case .hyphen: mark(start, end, .string)
            case .at: mark(start, end, .meta)
            default: break
            }
            index = end
            while index < count, units[index].isLineBreak {
                index += 1
            }
        }
    }

    // MARK: - Helpers

    /// Colours `start..<end` and moves past it.
    private mutating func mark(_ start: Int, _ end: Int, _ token: SyntaxToken) {
        index = max(index, end)
        guard end > start else { return }
        map[NSRange(location: start, length: end - start)] = token
    }

    private func matches(_ pattern: [UInt16], at start: Int) -> Bool {
        guard start + pattern.count <= units.count else { return false }
        for offset in 0 ..< pattern.count where units[start + offset] != pattern[offset] {
            return false
        }
        return true
    }

    private func find(_ pattern: [UInt16], from start: Int) -> Int? {
        guard let first = pattern.first else { return nil }
        var cursor = start
        while cursor + pattern.count <= units.count {
            if units[cursor] == first, matches(pattern, at: cursor) {
                return cursor
            }
            cursor += 1
        }
        return nil
    }

    private func lineEnd(from start: Int) -> Int {
        var cursor = start
        while cursor < units.count, !units[cursor].isLineBreak {
            cursor += 1
        }
        return cursor
    }
}
