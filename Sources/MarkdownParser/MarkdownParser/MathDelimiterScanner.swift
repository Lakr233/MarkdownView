import Foundation

/// Hand-written matchers for the two math patterns the parser used to run
/// through `NSRegularExpression`. Each returns what that regex's
/// `matches(in:range:)` returned over the whole text, in UTF-16 offsets, and
/// `MathDelimiterScannerTests` checks that against the regex itself.
///
/// The regex engine walks code points, but every delimiter here is ASCII and
/// never sits inside a surrogate pair, so walking UTF-16 units finds the same
/// positions.
enum MathDelimiterScanner {
    struct Match: Equatable {
        /// The whole match, delimiters included.
        let range: NSRange
        /// The math between the delimiters.
        let contentRange: NSRange
    }

    /// Matches of the document-level pattern, tried in this order at each
    /// position:
    ///
    ///     \$\$([\s\S]*?)\$\$
    ///     \\\\\[([\s\S]*?)\\\\\]
    ///     \\\\\(([\s\S]*?)\\\\\)
    ///     \\\[([\s\S]*?)\\\]
    ///     \\\(([^`\n]*?)\\\)
    static func delimitedMath(in units: [UInt16]) -> [Match] {
        var matches: [Match] = []
        var closers = CloserCache()
        var index = 0
        let count = units.count
        while index + 1 < count {
            let match: Match? = switch (units[index], units[index + 1]) {
            case (dollar, dollar):
                closers.closer(.dollars, from: index + 2, in: units).map {
                    Match(index, contentStart: index + 2, contentEnd: $0, closerLength: 2)
                }
            case (backslash, backslash) where index + 2 < count && units[index + 2] == openBracket:
                closers.closer(.doubleBackslashBracket, from: index + 3, in: units).map {
                    Match(index, contentStart: index + 3, contentEnd: $0, closerLength: 3)
                }
            case (backslash, backslash) where index + 2 < count && units[index + 2] == openParen:
                closers.closer(.doubleBackslashParen, from: index + 3, in: units).map {
                    Match(index, contentStart: index + 3, contentEnd: $0, closerLength: 3)
                }
            case (backslash, openBracket):
                closers.closer(.backslashBracket, from: index + 2, in: units).map {
                    Match(index, contentStart: index + 2, contentEnd: $0, closerLength: 2)
                }
            case (backslash, openParen):
                singleLineParenCloser(from: index + 2, in: units).map {
                    Match(index, contentStart: index + 2, contentEnd: $0, closerLength: 2)
                }
            default:
                nil
            }
            if let match {
                matches.append(match)
                index = match.range.location + match.range.length
            } else {
                index += 1
            }
        }
        return matches
    }

    /// Matches of the pattern run on each text node, tried in this order at
    /// each position:
    ///
    ///     \\\(([^\r\n]+?)\\\)
    ///     (?<![\d$])\$(?=\S)([^\r\n$]+?)(?<=\S)\$(?!\d)
    static func inlineMath(in units: [UInt16]) -> [Match] {
        var matches: [Match] = []
        var index = 0
        let count = units.count
        while index + 1 < count {
            let match: Match? = switch units[index] {
            case backslash where units[index + 1] == openParen:
                inlineParenCloser(from: index + 2, in: units).map {
                    Match(index, contentStart: index + 2, contentEnd: $0, closerLength: 2)
                }
            case dollar:
                inlineDollarCloser(opener: index, in: units).map {
                    Match(index, contentStart: index + 1, contentEnd: $0, closerLength: 1)
                }
            default:
                nil
            }
            if let match {
                matches.append(match)
                index = match.range.location + match.range.length
            } else {
                index += 1
            }
        }
        return matches
    }
}

private let dollar = UInt16(UInt8(ascii: "$"))
private let backslash = UInt16(UInt8(ascii: "\\"))
private let openBracket = UInt16(UInt8(ascii: "["))
private let closeBracket = UInt16(UInt8(ascii: "]"))
private let openParen = UInt16(UInt8(ascii: "("))
private let closeParen = UInt16(UInt8(ascii: ")"))
private let backtick = UInt16(UInt8(ascii: "`"))
private let lineFeed = UInt16(UInt8(ascii: "\n"))
private let carriageReturn = UInt16(UInt8(ascii: "\r"))

private extension MathDelimiterScanner.Match {
    init(_ start: Int, contentStart: Int, contentEnd: Int, closerLength: Int) {
        range = NSRange(location: start, length: contentEnd + closerLength - start)
        contentRange = NSRange(location: contentStart, length: contentEnd - contentStart)
    }
}

/// The closers whose content may span anything, so the earliest one at or
/// after a position is all that matters.
private enum Closer: CaseIterable {
    case dollars
    case doubleBackslashBracket
    case doubleBackslashParen
    case backslashBracket

    var units: [UInt16] {
        switch self {
        case .dollars: [dollar, dollar]
        case .doubleBackslashBracket: [backslash, backslash, closeBracket]
        case .doubleBackslashParen: [backslash, backslash, closeParen]
        case .backslashBracket: [backslash, closeBracket]
        }
    }
}

/// Remembers each closer search, so an opener that never closes costs one
/// scan to the end instead of one per later opener.
private struct CloserCache {
    /// For each closer: where a search began and the earliest closer found
    /// from there, or nil when there was none.
    private var searches: [Closer: (start: Int, found: Int?)] = [:]

    mutating func closer(_ closer: Closer, from start: Int, in units: [UInt16]) -> Int? {
        // No closer lies between a past search's start and what it found, so
        // its answer holds for any start in that span, or past it when it
        // found none.
        if let search = searches[closer], search.start <= start {
            if let found = search.found {
                if found >= start {
                    return found
                }
            } else {
                return nil
            }
        }
        let found = firstOccurrence(of: closer.units, from: start, in: units)
        searches[closer] = (start, found)
        return found
    }

    private func firstOccurrence(of needle: [UInt16], from start: Int, in units: [UInt16]) -> Int? {
        var index = start
        let last = units.count - needle.count
        while index <= last {
            if units[index] == needle[0] {
                var offset = 1
                while offset < needle.count, units[index + offset] == needle[offset] {
                    offset += 1
                }
                if offset == needle.count {
                    return index
                }
            }
            index += 1
        }
        return nil
    }
}

/// `\)` after `start`, the content between holding no backtick or newline.
private func singleLineParenCloser(from start: Int, in units: [UInt16]) -> Int? {
    var index = start
    while index + 1 < units.count {
        if units[index] == backslash, units[index + 1] == closeParen {
            return index
        }
        if units[index] == backtick || units[index] == lineFeed {
            return nil
        }
        index += 1
    }
    return nil
}

/// `\)` after at least one unit past `start`, with no line break between.
private func inlineParenCloser(from start: Int, in units: [UInt16]) -> Int? {
    var index = start
    while index < units.count {
        if index > start, index + 1 < units.count, units[index] == backslash, units[index + 1] == closeParen {
            return index
        }
        if units[index] == carriageReturn || units[index] == lineFeed {
            return nil
        }
        index += 1
    }
    return nil
}

/// The closing `$` for an opener at `opener`: the next `$` on the line, with
/// non-space on both inner sides and no digit on either outer side.
private func inlineDollarCloser(opener: Int, in units: [UInt16]) -> Int? {
    if let previous = scalar(endingAt: opener, in: units),
       previous == "$" || isRegexDigit(previous)
    {
        return nil
    }
    guard let first = scalar(startingAt: opener + 1, in: units), !isRegexWhitespace(first) else {
        return nil
    }
    var index = opener + 1
    while index < units.count {
        switch units[index] {
        case carriageReturn, lineFeed:
            return nil
        case dollar:
            guard index > opener + 1,
                  let last = scalar(endingAt: index, in: units), !isRegexWhitespace(last)
            else { return nil }
            if let next = scalar(startingAt: index + 1, in: units), isRegexDigit(next) {
                return nil
            }
            return index
        default:
            index += 1
        }
    }
    return nil
}

/// `\d`: a decimal digit in any script.
func isRegexDigit(_ scalar: Unicode.Scalar) -> Bool {
    scalar.properties.generalCategory == .decimalNumber
}

/// `\s`, which ICU defines by the Unicode White_Space property.
func isRegexWhitespace(_ scalar: Unicode.Scalar) -> Bool {
    scalar.properties.isWhitespace
}

/// The code point that ends just before `index`; a lone surrogate reads as a
/// replacement character, which is neither a digit nor white space.
private func scalar(endingAt index: Int, in units: [UInt16]) -> Unicode.Scalar? {
    guard index > 0 else { return nil }
    let unit = units[index - 1]
    if UTF16.isTrailSurrogate(unit), index >= 2, UTF16.isLeadSurrogate(units[index - 2]) {
        return UTF16.decode(UTF16.EncodedScalar([units[index - 2], unit]))
    }
    return Unicode.Scalar(unit) ?? "\u{FFFD}"
}

/// The code point that starts at `index`; a lone surrogate reads as a
/// replacement character, which is neither a digit nor white space.
private func scalar(startingAt index: Int, in units: [UInt16]) -> Unicode.Scalar? {
    guard index < units.count else { return nil }
    let unit = units[index]
    if UTF16.isLeadSurrogate(unit), index + 1 < units.count, UTF16.isTrailSurrogate(units[index + 1]) {
        return UTF16.decode(UTF16.EncodedScalar([unit, units[index + 1]]))
    }
    return Unicode.Scalar(unit) ?? "\u{FFFD}"
}
