import Foundation
@testable import MarkdownParser
import Testing

/// The scanners replaced two regexes; these run the regexes as the reference
/// and require the same matches on everything thrown at both.
struct MathDelimiterScannerTests {
    private static let delimitedPattern = try! NSRegularExpression(
        pattern: [
            ###"\$\$([\s\S]*?)\$\$"###,
            ###"\\\\\[([\s\S]*?)\\\\\]"###,
            ###"\\\\\(([\s\S]*?)\\\\\)"###,
            ###"\\\[([\s\S]*?)\\\]"###,
            ###"\\\(([^`\n]*?)\\\)"###,
        ].joined(separator: "|"),
        options: [.caseInsensitive],
    )

    private static let inlinePattern = try! NSRegularExpression(
        pattern: [
            ###"\\\(([^\r\n]+?)\\\)"###,
            ###"(?<![\d$])\$(?=\S)([^\r\n$]+?)(?<=\S)\$(?!\d)"###,
        ].joined(separator: "|"),
        options: [.caseInsensitive],
    )

    private static func regexMatches(_ regex: NSRegularExpression, in text: String) -> [MathDelimiterScanner.Match] {
        let length = (text as NSString).length
        return regex.matches(in: text, range: NSRange(location: 0, length: length)).map { match in
            let content = (1 ..< match.numberOfRanges)
                .map { match.range(at: $0) }
                .first { $0.location != NSNotFound }!
            return MathDelimiterScanner.Match(range: match.range, contentRange: content)
        }
    }

    private static let tokens: [String] = [
        "$", "$$", "$$$", "\\", "\\\\", "\\(", "\\)", "\\[", "\\]", "\\\\(", "\\\\)", "\\\\[", "\\\\]",
        "(", ")", "[", "]", "`", "```", "\n", "\r", "\r\n", "\n\n", " ", "\t", "\u{0B}", "\u{0C}",
        "\u{85}", "\u{A0}", "\u{2003}", "\u{3000}", "\u{2028}", "\u{200B}", "\u{FEFF}",
        "a", "x^2", "1", "5", "10", "٣", "५", "１", "𝟙", "½", "Ⅳ", "中", "🎉", "👨‍👩‍👧", "é", "e\u{301}",
    ]

    private static func corpus() -> [String] {
        var generator = SplitMix64(seed: 0x5343_414E)
        var texts = (0 ..< 20000).map { _ in
            let length = Int(generator.next() % 24)
            return (0 ..< length).map { _ in tokens[Int(generator.next() % UInt64(tokens.count))] }.joined()
        }
        texts += [
            "", "$", "$$", "$a$", "$ a$", "$a $", "1$a$", "$a$1", "$$a$$", "$a$$b$", "\\(\\)", "\\( \\)",
            "\\[x\\]", "\\\\[x\\\\]", "\\\\(x\\\\)", "\\(a`b\\)", "\\(a\nb\\)", "\\(a\rb\\)", "$$ unclosed",
            "$5 and $10", "costs $5.", "$x$y$z$", "$\u{A0}x$", "$x\u{85}$", "$x$٣", "٣$x$",
            String(repeating: "$$", count: 3) + String(repeating: "\\[", count: 4) + "\\]",
        ]
        return texts
    }

    @Test
    func `Delimited math scanner matches the regex`() {
        for text in Self.corpus() {
            let expected = Self.regexMatches(Self.delimitedPattern, in: text)
            #expect(MathDelimiterScanner.delimitedMath(in: Array(text.utf16)) == expected, "\(text.debugDescription)")
        }
    }

    @Test
    func `Inline math scanner matches the regex`() {
        for text in Self.corpus() {
            let expected = Self.regexMatches(Self.inlinePattern, in: text)
            #expect(MathDelimiterScanner.inlineMath(in: Array(text.utf16)) == expected, "\(text.debugDescription)")
        }
    }

    /// Every scalar at once: the regex's `\s` and `\d` against the predicates
    /// the inline scanner uses for them, on this system's Unicode data.
    @Test
    func `Character classes agree with the regex engine for every scalar`() throws {
        var scalars = String.UnicodeScalarView()
        var offsets: [Int] = []
        var offset = 0
        for value in UInt32(0) ... 0x10FFFF {
            guard let scalar = Unicode.Scalar(value) else { continue }
            scalars.append(scalar)
            offsets.append(offset)
            offset += scalar.utf16.count
        }
        let text = String(scalars)
        let all = Array(scalars)
        let range = NSRange(location: 0, length: offset)
        for (pattern, predicate) in [(#"\s"#, isRegexWhitespace), (#"\d"#, isRegexDigit)] {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matched = Set(regex.matches(in: text, range: range).map(\.range.location))
            let expected = Set(zip(offsets, all).filter { predicate($0.1) }.map(\.0))
            #expect(matched == expected, "\(pattern) differs at \(matched.symmetricDifference(expected).sorted().prefix(8))")
        }
    }
}
