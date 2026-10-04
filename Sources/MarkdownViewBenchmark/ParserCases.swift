import Foundation
import MarkdownParser

// MARK: - Parser

extension MarkdownViewBenchmark {
    /// The parser alone, on documents shaped like the answers a model streams.
    ///
    /// `parser/doc/*` parses one whole document per operation. `parser/stream/*`
    /// parses every prefix of a long document at a fixed step, the way a
    /// streamed answer is reparsed on each update, and reports the average
    /// parse; later prefixes cost more, so read it against `parser/doc/*` at
    /// the same size.
    @MainActor
    static func parserCases() -> [BenchmarkCase] {
        let parser = MarkdownParser()
        var cases: [BenchmarkCase] = []

        func documentCase(_ name: String, _ markdown: String) {
            // Small documents are batched so one operation is long enough to time.
            let operations = max(1, 65536 / max(1, markdown.utf8.count))
            cases.append(BenchmarkCase(
                name: "parser/doc/\(name)",
                operations: operations,
            ) { iterations in
                for _ in 0 ..< iterations * operations {
                    autoreleasepool { _ = parser.parse(markdown) }
                }
            })
        }

        for fixture in ["ExampleDocument", "MultilingualStress"] {
            guard let markdown = parserFixture(named: fixture) else { continue }
            documentCase("fixture_\(fixture)", markdown)
        }

        let longSize = 64 * 1024
        let shapes: [(String, (Int) -> String)] = [
            ("mixed", parserMixedDocument(size:)),
            ("prose", parserProseDocument(size:)),
            ("code", parserCodeDocument(size:)),
            ("table", parserTableDocument(size:)),
            ("math", parserMathDocument(size:)),
            ("list_quote", parserListQuoteDocument(size:)),
            ("cjk", parserCJKDocument(size:)),
        ]
        documentCase("mixed_8k", parserMixedDocument(size: 8 * 1024))
        for (name, make) in shapes {
            documentCase("\(name)_64k", make(longSize))
        }

        // Every 256th byte of a 64 KB document: 256 parses per sweep.
        for (name, make) in shapes {
            let prefixes = parserPrefixes(of: make(longSize), step: 256)
            cases.append(BenchmarkCase(
                name: "parser/stream/\(name)_64k",
                operations: prefixes.count,
                iterationLimit: 3,
            ) { iterations in
                for _ in 0 ..< iterations {
                    for prefix in prefixes {
                        autoreleasepool { _ = parser.parse(prefix) }
                    }
                }
            })
        }
        return cases
    }
}

/// A fixture from the view tests, read from the source tree.
private func parserFixture(named name: String) -> String? {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Tests/MarkdownViewTests/Fixtures/\(name).md")
    return try? String(contentsOf: url, encoding: .utf8)
}

/// Prefixes of `markdown` every `step` UTF-8 bytes, cut back to a scalar
/// boundary, ending with the whole document.
private func parserPrefixes(of markdown: String, step: Int) -> [String] {
    var prefixes: [String] = []
    var offset = step
    let utf8 = markdown.utf8
    while offset < utf8.count {
        var index = utf8.index(utf8.startIndex, offsetBy: offset)
        while index.samePosition(in: markdown.unicodeScalars) == nil {
            index = utf8.index(before: index)
        }
        prefixes.append(String(markdown[..<index]))
        offset += step
    }
    prefixes.append(markdown)
    return prefixes
}

/// Repeats `section` with a growing index until the document reaches `size`
/// UTF-8 bytes.
private func parserRepeat(size: Int, header: String, section: (Int) -> String) -> String {
    var out = header
    var index = 1
    while out.utf8.count < size {
        out += section(index)
        index += 1
    }
    return out
}

private func parserMixedDocument(size: Int) -> String {
    parserRepeat(size: size, header: "# Mixed Answer 混合回答\n\n") { index in
        """
        ## Section \(index) 第 \(index) 节

        A paragraph with **bold**, *emphasis*, `inline code`, ~~struck~~ text and \
        a [link](https://example.com/\(index)). 中文内容与 English 混排，$x_\(index)^2$ 公式。

        - item \(index).1 with `code`
        - [ ] task \(index).2
        - [x] task \(index).3

        > Quoted line \(index): a model often quotes the question back.

        ```python
        def f\(index)(x):
            return x * \(index)
        ```

        | Key | Value |
        | :-- | --: |
        | k\(index) | \(index * 7) |

        $$
        \\sum_{i=1}^{\(index)} i = \\frac{n(n+1)}{2}
        $$


        """
    }
}

private func parserProseDocument(size: Int) -> String {
    parserRepeat(size: size, header: "# Prose\n\n") { index in
        """
        Paragraph \(index) explains the idea at length. It carries **strong words**, \
        *gentle emphasis*, a `symbol_\(index)` and a [reference](https://example.com/p/\(index)) \
        so the inline parser has real work, and it keeps going for several sentences \
        because answers do: the costs scale with prose, not with exotic syntax. \
        Prices like $5 and $10 must stay text, and so must a lone backslash \\ here.
        Soft-wrapped second line of paragraph \(index), ending with a hard break
        and one more line after it.


        """
    }
}

private func parserCodeDocument(size: Int) -> String {
    parserRepeat(size: size, header: "# Code\n\n") { index in
        """
        Step \(index): run the following.

        ```swift
        struct Model\(index): Codable {
            let id: Int
            let name: String
            func matches(_ query: String) -> Bool {
                name.localizedCaseInsensitiveContains(query) && id > \(index)
            }
        }
        // price is $\(index) and the regex is \\(a|b\\)
        ```

        ```bash
        export VALUE_\(index)="$HOME/bin"
        echo "${VALUE_\(index)}" | grep -E '\\[[0-9]+\\]'
        ```


        """
    }
}

private func parserTableDocument(size: Int) -> String {
    parserRepeat(size: size, header: "# Tables\n\n") { index in
        var out = "Comparison \(index):\n\n| Name | 名称 | Score | Note |\n| :-- | :-: | --: | --- |\n"
        for row in 1 ... 12 {
            out += "| item \(index).\(row) | 项目 \(row) | \(row * index % 997) | `v\(row)` **ok** |\n"
        }
        return out + "\n"
    }
}

private func parserMathDocument(size: Int) -> String {
    parserRepeat(size: size, header: "# Math\n\n") { index in
        """
        Let $a_\(index) = \\alpha + \\beta$ and $b_\(index) = a_\(index)^2$, so \\(c = a + b\\) holds.

        $$
        \\int_0^{\(index)} x^2 \\, dx = \\frac{\(index)^3}{3}
        $$

        \\[
        E_\(index) = mc^2 + \\sum_{k=0}^{n} \\binom{n}{k}
        \\]

        Inline money like $5 stays text, while $\\sqrt{\(index)}$ is math.


        """
    }
}

private func parserListQuoteDocument(size: Int) -> String {
    parserRepeat(size: size, header: "# Lists\n\n") { index in
        """
        1. First \(index)
           - nested bullet with **bold**
           - nested bullet with `code`
             > quote inside a list
        2. Second \(index)
           1. deeper ordered
           2. deeper again
        - [ ] open task \(index)
        - [x] done task \(index)

        > Quote \(index) opens here
        > > nested quote with *emphasis*
        > - list in quote
        > - another


        """
    }
}

private func parserCJKDocument(size: Int) -> String {
    parserRepeat(size: size, header: "# 中文长文\n\n") { index in
        """
        第 \(index) 段：这是一段较长的中文说明，包含**加粗内容**、*强调内容*、`行内代码`以及\
        [一个链接](https://example.com/zh/\(index))。日本語のかなも少し混ざり、한국어 문장도 \
        들어갑니다。表情符号 🎉🚀 和全角标点「引号」『书名号』也会出现。

        - 要点 \(index).1：说明文字
        - 要点 \(index).2：更多说明


        """
    }
}
