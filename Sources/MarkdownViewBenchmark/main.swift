import Foundation
import MarkdownParser
import MarkdownView

struct BenchmarkCase {
    let name: String
    /// Sub-operations one iteration performs.
    ///
    /// A stream of 120 updates and a single render are both one iteration, so
    /// without this their averages are not on the same scale. `op_ms` divides
    /// by this and is the number to compare across cases.
    let operations: Int
    /// Ceiling for this case, for the ones too expensive to run the full count.
    let iterationLimit: Int?
    let run: @MainActor (_ iterations: Int) -> Void

    init(
        name: String,
        operations: Int = 1,
        iterationLimit: Int? = nil,
        run: @escaping @MainActor (_ iterations: Int) -> Void
    ) {
        self.name = name
        self.operations = operations
        self.iterationLimit = iterationLimit
        self.run = run
    }
}

@main
struct MarkdownViewBenchmark {
    @MainActor
    static func main() {
        let configuration = Configuration(arguments: CommandLine.arguments)
        let cases = benchmarkCases().filter { benchmark in
            guard let filter = configuration.filter else { return true }
            return benchmark.name.contains(filter)
        }

        for benchmark in cases {
            let iterations = min(
                configuration.iterations,
                benchmark.iterationLimit ?? .max
            )
            for _ in 0 ..< configuration.warmupIterations {
                benchmark.run(1)
            }

            let started = ContinuousClock.now
            benchmark.run(iterations)
            let elapsed = ContinuousClock.now - started
            let totalMilliseconds = Double(elapsed.components.seconds) * 1000
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
            let averageMilliseconds = totalMilliseconds / Double(iterations)
            let operationMilliseconds = averageMilliseconds / Double(benchmark.operations)

            print(
                "BENCHMARK \(benchmark.name)"
                    + " total_ms=\(format(totalMilliseconds))"
                    + " avg_ms=\(format(averageMilliseconds))"
                    + " op_ms=\(format(operationMilliseconds))"
                    + " iterations=\(iterations)"
                    + " ops=\(benchmark.operations)"
            )
        }
    }

    @MainActor
    private static func benchmarkCases() -> [BenchmarkCase] {
        legacyCases() + scalingCases() + streamingCases() + shapeCases()
    }

    // MARK: - Cases carried over from the original benchmark

    /// The original five cases, unchanged, so numbers recorded before this file
    /// grew stay comparable with numbers recorded after it.
    @MainActor
    private static func legacyCases() -> [BenchmarkCase] {
        let theme = MarkdownTheme.default
        let markdown = benchmarkMarkdown
        let tableHeavyMarkdown = benchmarkTableHeavyMarkdown
        let parser = MarkdownParser()
        let parsed = parser.parse(markdown)
        let tableHeavyParsed = parser.parse(tableHeavyMarkdown)
        let preprocessed = MarkdownContent(
            parserResult: parsed,
            theme: theme
        )
        let tableHeavyPreprocessed = MarkdownContent(
            parserResult: tableHeavyParsed,
            theme: theme
        )

        return [
            BenchmarkCase(name: "parse") { iterations in
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        _ = parser.parse(markdown)
                    }
                }
            },
            BenchmarkCase(name: "preprocess") { iterations in
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        let result = parser.parse(markdown)
                        _ = MarkdownContent(
                            parserResult: result,
                            theme: theme
                        )
                    }
                }
            },
            BenchmarkCase(name: "layout") { iterations in
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        let view = MarkdownTextView()
                        view.setContentImmediately(preprocessed)
                        _ = view.boundingSize(for: 480)
                        _ = view.boundingSize(for: 320)
                        _ = view.boundingSize(for: 200)
                    }
                }
            },
            BenchmarkCase(name: "update_reuse") { iterations in
                let view = MarkdownTextView()
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        view.setContentImmediately(preprocessed)
                        _ = view.boundingSize(for: 320)
                    }
                }
            },
            BenchmarkCase(name: "table_refresh_heavy") { iterations in
                let view = MarkdownTextView()
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        view.setContentImmediately(tableHeavyPreprocessed)
                        _ = view.boundingSize(for: 320)
                    }
                }
            },
        ]
    }

    // MARK: - How the cost grows with the document

    /// The same document at four sizes, split into the three phases a caller
    /// pays for separately.
    ///
    /// Rebuilding is per-document work repeated on every update, so a phase that
    /// grows linearly here turns into quadratic cost over a stream. Reading
    /// `op_ms` down a column is how that shows up.
    @MainActor
    private static func scalingCases() -> [BenchmarkCase] {
        let theme = MarkdownTheme.default
        let parser = MarkdownParser()
        var cases: [BenchmarkCase] = []

        for sections in [1, 4, 16] {
            let markdown = benchmarkDocument(sections: sections)
            let parsed = parser.parse(markdown)
            let content = MarkdownContent(parserResult: parsed, theme: theme)

            cases.append(BenchmarkCase(name: "scale/parse/\(sections)") { iterations in
                for _ in 0 ..< iterations {
                    autoreleasepool { _ = parser.parse(markdown) }
                }
            })
            cases.append(BenchmarkCase(name: "scale/content/\(sections)") { iterations in
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        _ = MarkdownContent(parserResult: parsed, theme: theme)
                    }
                }
            })
            // The rebuild proper: everything between "content is ready" and
            // "the document is typeset and measured".
            cases.append(BenchmarkCase(name: "scale/build/\(sections)") { iterations in
                let view = MarkdownTextView()
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        view.setContentImmediately(content)
                        _ = view.boundingSize(for: 600)
                    }
                }
            })
        }

        return cases
    }

    // MARK: - Streaming, the workload that actually hurts

    /// A document arriving in prefixes, the way a model streams one.
    ///
    /// Each update parses and rebuilds the whole document, so the per-update
    /// cost tracks the length reached so far and the run as a whole is
    /// quadratic. `op_ms` is the average update; watching it move between
    /// `stream/4` and `stream/16` says whether that is still true.
    @MainActor
    private static func streamingCases() -> [BenchmarkCase] {
        let theme = MarkdownTheme.default
        let parser = MarkdownParser()
        var cases: [BenchmarkCase] = []

        for sections in [4, 16] {
            let prefixes = streamingPrefixes(
                of: benchmarkDocument(sections: sections),
                updates: 120
            )
            cases.append(BenchmarkCase(
                name: "stream/\(sections)",
                operations: prefixes.count,
                iterationLimit: 3
            ) { iterations in
                for _ in 0 ..< iterations {
                    let view = MarkdownTextView()
                    for prefix in prefixes {
                        autoreleasepool {
                            let content = MarkdownContent(
                                parserResult: parser.parse(prefix),
                                theme: theme
                            )
                            view.setContentImmediately(content)
                            _ = view.boundingSize(for: 600)
                        }
                    }
                }
            })
        }

        // The tail of a long answer, where every update already carries the
        // whole document. This is the worst update a reader ever waits on.
        let longPrefixes = Array(
            streamingPrefixes(of: benchmarkDocument(sections: 16), updates: 120)
                .suffix(20)
        )
        cases.append(BenchmarkCase(
            name: "stream/tail_16",
            operations: longPrefixes.count,
            iterationLimit: 5
        ) { iterations in
            for _ in 0 ..< iterations {
                let view = MarkdownTextView()
                for prefix in longPrefixes {
                    autoreleasepool {
                        let content = MarkdownContent(
                            parserResult: parser.parse(prefix),
                            theme: theme
                        )
                        view.setContentImmediately(content)
                        _ = view.boundingSize(for: 600)
                    }
                }
            }
        })

        return cases
    }

    // MARK: - Documents weighted towards one kind of content

    /// Same total length, different content, so a change can be attributed.
    ///
    /// Inline-heavy leans on the per-text-node work; the other three lean on
    /// their own block processors.
    @MainActor
    private static func shapeCases() -> [BenchmarkCase] {
        let theme = MarkdownTheme.default
        let parser = MarkdownParser()

        let shapes: [(String, String)] = [
            ("inline_heavy", inlineHeavyMarkdown),
            ("list_heavy", listHeavyMarkdown),
            ("code_heavy", codeHeavyMarkdown),
            ("latin_only", latinOnlyMarkdown),
        ]

        var cases = shapes.map { name, markdown in
            let content = MarkdownContent(
                parserResult: parser.parse(markdown),
                theme: theme
            )
            return BenchmarkCase(name: "shape/\(name)") { iterations in
                let view = MarkdownTextView()
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        view.setContentImmediately(content)
                        _ = view.boundingSize(for: 600)
                    }
                }
            }
        }

        // Re-measuring at a width the view has already seen must not re-typeset.
        // A regression here is invisible in every other case.
        let content = MarkdownContent(
            parserResult: parser.parse(benchmarkDocument(sections: 4)),
            theme: theme
        )
        cases.append(BenchmarkCase(name: "measure/repeat_width", operations: 8) { iterations in
            let view = MarkdownTextView()
            view.setContentImmediately(content)
            _ = view.boundingSize(for: 600)
            for _ in 0 ..< iterations {
                for _ in 0 ..< 8 {
                    _ = view.boundingSize(for: 600)
                }
            }
        })
        cases.append(BenchmarkCase(name: "measure/changing_width", operations: 8) { iterations in
            let view = MarkdownTextView()
            view.setContentImmediately(content)
            for _ in 0 ..< iterations {
                for step in 0 ..< 8 {
                    _ = view.boundingSize(for: 400 + CGFloat(step) * 37)
                }
            }
        })

        return cases
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private struct Configuration {
    let iterations: Int
    let warmupIterations: Int
    /// Run only the cases whose name contains this, for iterating on one of them.
    let filter: String?

    init(arguments: [String]) {
        iterations = Self.value(for: "--iterations", in: arguments) ?? 30
        warmupIterations = Self.value(for: "--warmup", in: arguments) ?? 3
        filter = Self.string(for: "--filter", in: arguments)
    }

    private static func value(for flag: String, in arguments: [String]) -> Int? {
        guard let raw = string(for: flag, in: arguments) else { return nil }
        return Int(raw)
    }

    private static func string(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }
}

// MARK: - Documents

/// Growing prefixes of `markdown`, split on character boundaries.
///
/// Prefixes are built up front so the cost of slicing never lands inside a
/// measured update.
private func streamingPrefixes(of markdown: String, updates: Int) -> [String] {
    let characters = Array(markdown)
    let step = max(1, characters.count / max(1, updates))
    var prefixes: [String] = []
    var cursor = 0
    while cursor < characters.count {
        cursor = min(characters.count, cursor + step)
        prefixes.append(String(characters[0 ..< cursor]))
    }
    return prefixes
}

/// A long assistant answer: mixed scripts, every block kind, `sections` of it.
private func benchmarkDocument(sections: Int) -> String {
    var out = "# 性能基准文档 Performance Baseline\n\n"
    for index in 1 ... max(1, sections) {
        out += """
        ## 第 \(index) 节 Section \(index)

        这是一个中等长度的段落，包含 **加粗**、*强调*、`inline code` 以及 \
        [链接](https://example.com/\(index))。English prose follows so the language \
        splitter has to switch scripts inside one paragraph, which is what an \
        assistant reply looks like in practice.

        - 列表项 \(index).1 with trailing English
        - 列表项 \(index).2 与另外一些中文内容
        - 列表项 \(index).3 `code span` inside a bullet

        1. 有序列表第一项
        2. 有序列表第二项
        3. 有序列表第三项

        > 引用块 \(index)：这里是一段被引用的文字，用于测试 blockquote 的排版开销。

        ```swift
        func handle\(index)(_ input: String) -> Int {
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            return trimmed.count &* \(index)
        }
        ```

        | 列 A | 列 B | 列 C |
        | :-- | :-: | --: |
        | 行 \(index) 单元格 | value \(index) | \(index * 1000) |
        | 第二行内容 | another | \(index * 2000) |


        """
    }
    return out
}

private let inlineHeavyMarkdown: String = (1 ... 40).map { index in
    """
    第 \(index) 段中文与 English mixed prose，带有 **加粗\(index)**、*强调\(index)*、\
    `code\(index)`、[链接\(index)](https://example.com/\(index)) 和 ~~删除线\(index)~~，\
    日本語かなも少し混ざっています。The paragraph is deliberately long so that the \
    inline renderer has plenty of text nodes to walk through on every rebuild.
    """
}.joined(separator: "\n\n")

private let listHeavyMarkdown: String = (1 ... 30).map { index in
    """
    - 第 \(index) 项 bullet item with trailing English text
      - 嵌套第 \(index) 项 nested item
    1. 有序第 \(index) 项
    - [\(index % 2 == 0 ? "x" : " ")] 任务第 \(index) 项
    """
}.joined(separator: "\n\n")

private let codeHeavyMarkdown: String = (1 ... 12).map { index in
    """
    段落 \(index) before the code block.

    ```swift
    struct Model\(index): Codable, Sendable {
        let identifier: Int
        let title: String
        let tags: [String]

        func matches(_ query: String) -> Bool {
            title.localizedCaseInsensitiveContains(query)
                || tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    ```
    """
}.joined(separator: "\n\n")

/// The same weight of text with no script switching, to separate the cost of
/// the language attributes from the cost of the text itself.
private let latinOnlyMarkdown: String = (1 ... 40).map { index in
    """
    Paragraph \(index) of plain latin prose with **bold\(index)**, *emphasis\(index)*, \
    `code\(index)`, [a link\(index)](https://example.com/\(index)) and ~~strike\(index)~~. \
    The paragraph is deliberately long so that the inline renderer has plenty of text \
    nodes to walk through on every single rebuild of the document.
    """
}.joined(separator: "\n\n")

private let benchmarkMarkdown = """
# 多语言レンダリング Benchmark

中文段落保持稳定。日本語かな交じりの文も同じ段落で扱う。English words stay selectable. العربية داخل الفقرة.

## 表格

| 语言 | 内容 | 备注 |
| --- | --- | --- |
| zh-Hans | 中文单元格<br>第二行 | 表格前后要连续选择 |
| ja | 日本語かなと漢字 | レイアウトの再利用 |
| mixed | ChatGPT 回复: 这是中文 / これは日本語かな / مرحبا | Mixed locale |

## Code

```swift
struct Message {
    let text: String
    let locale: String
}

let samples = [
    Message(text: "中文 日本語かな العربية", locale: "mixed"),
    Message(text: "第二行用于测试换行", locale: "zh-Hans"),
]

for sample in samples {
    print(sample.locale, sample.text)
}
```

- 第一项 with English
- 第二項目かな
- بند عربي

> 引用块里也要稳定。
"""

private let benchmarkTableHeavyMarkdown = """
# Table Heavy

| 列1 | 列2 | 列3 | 列4 |
| --- | --- | --- | --- |
| 中文 01 | 日本語かな 01 | العربية 01 | English 01 |
| 中文 02 | 日本語かな 02 | العربية 02 | English 02 |
| 中文 03 | 日本語かな 03 | العربية 03 | English 03 |
| 中文 04 | 日本語かな 04 | العربية 04 | English 04 |
| 中文 05 | 日本語かな 05 | العربية 05 | English 05 |
| 中文 06 | 日本語かな 06 | العربية 06 | English 06 |
| 中文 07 | 日本語かな 07 | العربية 07 | English 07 |
| 中文 08 | 日本語かな 08 | العربية 08 | English 08 |
| 中文 09 | 日本語かな 09 | العربية 09 | English 09 |
| 中文 10 | 日本語かな 10 | العربية 10 | English 10 |
| 中文 11 | 日本語かな 11 | العربية 11 | English 11 |
| 中文 12 | 日本語かな 12 | العربية 12 | English 12 |
"""
