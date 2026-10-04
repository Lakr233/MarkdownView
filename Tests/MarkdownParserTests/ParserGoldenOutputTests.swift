import Foundation
@testable import MarkdownParser
import Testing

/// Pins the parser's output on a broad corpus, so a change made for speed
/// cannot change what a document parses to.
///
/// Each corpus group hashes the JSON encoding of every parse result in it;
/// `ParserGoldenHashes.swift` holds the hashes taken before the parser was
/// optimized. A change that is meant to alter output regenerates that file:
/// run this suite with `PARSER_GOLDEN_PRINT=1` and paste what it prints.
struct ParserGoldenOutputTests {
    @Test
    func `Parse output matches the recorded golden hashes`() throws {
        let parser = MarkdownParser()
        var actual: [String: String] = [:]
        for group in ParserGoldenCorpus.groups() {
            var hasher = StableHasher()
            for document in group.documents {
                try hasher.combine(encodedResult(parser.parse(document)))
            }
            actual[group.name] = hasher.hexDigest
        }

        if ProcessInfo.processInfo.environment["PARSER_GOLDEN_PRINT"] != nil {
            print("let parserGoldenHashes: [String: String] = [")
            for name in actual.keys.sorted() {
                print("    \"\(name)\": \"\(actual[name]!)\",")
            }
            print("]")
        }

        #expect(Set(actual.keys) == Set(parserGoldenHashes.keys))
        for name in actual.keys.sorted() {
            #expect(actual[name] == parserGoldenHashes[name], "\(name) parses differently")
        }
    }

    private struct EncodedResult: Encodable {
        let document: [MarkdownBlockNode]
        let mathContext: [Int: String]
    }

    private func encodedResult(_ result: MarkdownParser.ParseResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(EncodedResult(document: result.document, mathContext: result.mathContext))
    }
}

/// FNV-1a, which unlike `Hasher` is the same in every process.
private struct StableHasher {
    private var state: UInt64 = 0xCBF2_9CE4_8422_2325

    mutating func combine(_ data: Data) {
        for byte in data {
            state = (state ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        // Separates documents, so moving bytes between two changes the hash.
        state = (state ^ 0xFF) &* 0x0000_0100_0000_01B3
    }

    var hexDigest: String {
        String(state, radix: 16)
    }
}

enum ParserGoldenCorpus {
    struct Group {
        let name: String
        let documents: [String]
    }

    static func groups() -> [Group] {
        var groups: [Group] = []
        for name in ["ExampleDocument", "MultilingualStress"] {
            guard let markdown = fixture(named: name) else {
                Issue.record("Missing fixture \(name)")
                continue
            }
            groups.append(Group(name: "fixture/\(name)", documents: [markdown]))
            groups.append(Group(name: "fixture/\(name)/prefixes", documents: prefixes(of: markdown, step: 7)))
            groups.append(Group(name: "fixture/\(name)/crlf", documents: [
                markdown.replacingOccurrences(of: "\n", with: "\r\n"),
            ]))
        }
        for (name, markdown) in snippets {
            groups.append(Group(name: "snippet/\(name)", documents: [markdown]))
            groups.append(Group(name: "snippet/\(name)/prefixes", documents: prefixes(of: markdown, step: 3)))
        }
        var generator = SplitMix64(seed: 0x4D61_726B_646F_776E)
        for batch in 0 ..< 40 {
            let documents = (0 ..< 100).map { _ in fuzzDocument(using: &generator) }
            groups.append(Group(name: "fuzz/\(batch)", documents: documents))
        }
        return groups
    }

    private static func fixture(named name: String) -> String? {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MarkdownViewTests/Fixtures/\(name).md")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Every prefix at `step` scalars, the way a streamed answer arrives.
    private static func prefixes(of markdown: String, step: Int) -> [String] {
        let scalars = Array(markdown.unicodeScalars)
        return stride(from: 0, through: scalars.count, by: step).map { end in
            var view = String.UnicodeScalarView()
            view.append(contentsOf: scalars[0 ..< end])
            return String(view)
        }
    }

    static let snippets: [(String, String)] = [
        ("math", """
        Let $a = \\alpha$ and $b_1 = a^2$, so \\(c = a + b\\) holds; $5 and $10 stay text, as does 3$x$4.

        $$
        \\int_0^1 x^2 \\, dx
        $$

        \\[
        E = mc^2
        \\]

        Escaped \\\\[x\\\\] and \\\\(y\\\\) forms, $$inline block$$ and `$$code$$`, `\\(z\\)`.

        ```
        $$ in a fence $$ and \\[ x \\]
        ```

            $$ in indented code $$

        | $x$ | \\(y\\) |
        | --- | --- |
        | $$z$$ | `$w$` |

        > quote with $q$ and $$Q$$
        - item with \\[ L \\] and $l$
        Unclosed $$ block and \\( open
        """),
        ("lists", """
        1. First
           - nested **bold**
           - nested `code`
             > quote inside a list
             ```swift
             let x = 1
             ```
        2. Second
           1. deeper
           2. deeper again
        5) other delimiter
        - [ ] open task
        - [x] done task
        - plain after tasks
        * star bullet

        - loose

        - list

        > Quote
        > > nested *emphasis*
        > - list in quote
        > # heading in quote
        > | a | b |
        > | - | - |
        > | 1 | 2 |
        > ---
        """),
        ("inline", """
        # Heading with *emph* and `code`
        Setext heading
        ===
        **strong *nested emph* ~~strike~~** _under_ __strong__ ***both***
        [link](https://example.com "title") ![image](a.png) <https://auto.link> www.example.com
        Hard break with spaces
        and backslash\\
        end. <b>inline html</b> &copy; &#x4E2D; \\*escaped\\*
        [ref]: https://example.com/ref
        [ref] and [missing]

        <div>
        html block
        </div>

        ---
        ***
        Emoji 👨‍👩‍👧‍👦 and CJK 中文、日本語、한국어 and RTL مرحبا.
        """),
        ("tables", """
        | Left | Center | Right | None |
        | :--- | :----: | ----: | ---- |
        | a | **b** | `c` | [d](e) |
        | 中文 | $x$ | \\| pipe | |
        | short |

        | only header |
        | --- |

        not | a | table
        """),
        ("code", """
        ```swift title="x"
        func f() -> Int { 1 }
        ```

        ~~~
        tilde fence
        ~~~

        ````markdown
        ```nested```
        ````

        ``code with ` backtick`` and ` spaced `
        ```
        unterminated fence $$x$$
        """),
    ]

    private static let fuzzTokens: [String] = [
        "a", "word ", "中文", "🎉", " ", "  ", "\n", "\n\n", "\r\n", "\t",
        "$", "$$", "\\(", "\\)", "\\[", "\\]", "\\\\(", "\\\\[", "\\", "x^2", "5",
        "`", "``", "```", "```swift\n", "~~~", "    ",
        "*", "**", "_", "__", "~~", "[", "]", "(", ")", "![", "](u)", "<", ">", "<b>", "</b>", "&amp;",
        "# ", "## ", "- ", "* ", "+ ", "1. ", "2) ", "> ", "- [ ] ", "- [x] ", "---\n", "===\n",
        "|", " | ", "| --- |", "|:-:|", "https://e.com", "md://content?type=math&identifier=0",
    ]

    private static func fuzzDocument(using generator: inout SplitMix64) -> String {
        let length = Int(generator.next() % 120)
        var out = ""
        for _ in 0 ..< length {
            out += fuzzTokens[Int(generator.next() % UInt64(fuzzTokens.count))]
        }
        return out
    }
}

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
