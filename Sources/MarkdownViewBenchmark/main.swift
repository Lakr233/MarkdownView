import Foundation
import MarkdownParser
import MarkdownView

struct BenchmarkCase {
    let name: String
    let run: @MainActor (_ iterations: Int) -> Void
}

@main
struct MarkdownViewBenchmark {
    @MainActor
    static func main() {
        let configuration = Configuration(arguments: CommandLine.arguments)
        let cases = benchmarkCases()

        for benchmark in cases {
            for _ in 0 ..< configuration.warmupIterations {
                benchmark.run(1)
            }

            let started = ContinuousClock.now
            benchmark.run(configuration.iterations)
            let elapsed = ContinuousClock.now - started
            let totalMilliseconds = Double(elapsed.components.seconds) * 1000
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
            let averageMilliseconds = totalMilliseconds / Double(configuration.iterations)

            print(
                "BENCHMARK \(benchmark.name) total_ms=\(format(totalMilliseconds)) avg_ms=\(format(averageMilliseconds)) iterations=\(configuration.iterations)"
            )
        }
    }

    @MainActor
    private static func benchmarkCases() -> [BenchmarkCase] {
        let theme = MarkdownTheme.default
        let markdown = benchmarkMarkdown
        let tableHeavyMarkdown = benchmarkTableHeavyMarkdown
        let parser = MarkdownParser()
        let parsed = parser.parse(markdown)
        let tableHeavyParsed = parser.parse(tableHeavyMarkdown)
        let preprocessed = MarkdownTextView.PreprocessedContent(
            parserResult: parsed,
            theme: theme
        )
        let tableHeavyPreprocessed = MarkdownTextView.PreprocessedContent(
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
                        _ = MarkdownTextView.PreprocessedContent(
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
                        view.setMarkdownManually(preprocessed)
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
                        view.setMarkdownManually(preprocessed)
                        _ = view.boundingSize(for: 320)
                    }
                }
            },
            BenchmarkCase(name: "table_refresh_heavy") { iterations in
                let view = MarkdownTextView()
                for _ in 0 ..< iterations {
                    autoreleasepool {
                        view.setMarkdownManually(tableHeavyPreprocessed)
                        _ = view.boundingSize(for: 320)
                    }
                }
            },
        ]
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private struct Configuration {
    let iterations: Int
    let warmupIterations: Int

    init(arguments: [String]) {
        iterations = Self.value(for: "--iterations", in: arguments) ?? 30
        warmupIterations = Self.value(for: "--warmup", in: arguments) ?? 3
    }

    private static func value(for flag: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else { return nil }
        return Int(arguments[index + 1])
    }
}

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
