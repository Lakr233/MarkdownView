//
//  CatalogSample.swift
//  MarkdownViewCatalog
//

import Foundation

/// One catalog page: a component and the markdown that exercises it.
struct CatalogSample: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let summary: String
    let markdown: String
}

extension CatalogSample {
    static let groups: [(title: String, samples: [CatalogSample])] = [
        ("Overview", [.chatAnswer, .everything]),
        ("Text", [.paragraphs, .inlineStyles, .headings, .links]),
        ("Blocks", [.lists, .tasks, .blockquotes, .codeBlocks, .tables, .math, .thematicBreaks]),
        ("Stress", [.narrow, .multilingual, .nesting]),
    ]

    static let all: [CatalogSample] = groups.flatMap(\.samples)

    static let chatAnswer = CatalogSample(
        id: "chat-answer",
        title: "Chat Answer",
        systemImage: "bubble.left",
        summary: "A typical assistant reply: prose, a list, a code block and a short table.",
        markdown: """
        Short answer: **use an `actor`** when the state is shared across tasks, and keep the UI on the `@MainActor`.

        Here is why it matters:

        1. An actor serializes access, so two tasks can't interleave a read and a write.
        2. Calls into it are `await`ed, which makes the suspension points visible.
        3. Value types that cross the boundary must be `Sendable`.

        ```swift
        actor Counter {
            private var value = 0

            func increment() -> Int {
                value += 1
                return value
            }
        }

        let counter = Counter()
        let next = await counter.increment()
        ```

        | Approach | Data-race safe | Blocks a thread |
        | :------- | :------------: | :-------------: |
        | `actor` | ✅ | No |
        | `NSLock` | ✅ | Yes |
        | `DispatchQueue` | ✅ | Sometimes |

        > If the type is only touched from the UI, `@MainActor` alone is enough — no actor needed.

        Let me know if you want the `async let` version too.
        """,
    )

    static let paragraphs = CatalogSample(
        id: "paragraphs",
        title: "Paragraphs",
        systemImage: "text.alignleft",
        summary: "Body copy, line height and the gap between paragraphs.",
        markdown: """
        Typography is what makes a long answer readable. This paragraph is long enough to wrap several times, so the line height, the measure and the color of the body text are all visible at once. A good body face disappears; you only notice it when it is wrong.

        A second paragraph follows, to show the spacing between paragraphs. It should read as a clear pause, smaller than the gap before a heading and larger than the gap between lines.
        A soft line break inside a paragraph stays in the same block,\\
        while a hard break (a trailing backslash) starts a new line.

        *A closing line in italics, as a footer would be.*
        """,
    )

    static let inlineStyles = CatalogSample(
        id: "inline-styles",
        title: "Inline Styles",
        systemImage: "bold",
        summary: "Emphasis, strong, strikethrough, inline code and escapes inside running text.",
        markdown: """
        Plain text, **bold**, *italic*, ***bold italic***, ~~strikethrough~~ and `inline code` side by side.

        **A whole sentence in bold, with `code` and *italic* nested inside it.**

        Inline code at different lengths: `x`, `let value = 42`, and a long one `URLSession.shared.dataTask(with:completionHandler:)` that may need to wrap.

        Escapes stay literal: \\*not italic\\*, \\`not code\\`, \\# not a heading.

        Entities: &copy; &amp; &rarr; &mdash; &nbsp;and typographic quotes “like these”.
        """,
    )

    static let headings = CatalogSample(
        id: "headings",
        title: "Headings",
        systemImage: "number",
        summary: "All six levels, each followed by body text to show the rhythm.",
        markdown: """
        # Heading level one
        Body text under a first-level heading.

        ## Heading level two
        Body text under a second-level heading.

        ### Heading level three
        Body text under a third-level heading.

        #### Heading level four
        Body text under a fourth-level heading.

        ##### Heading level five
        Body text under a fifth-level heading.

        ###### Heading level six
        Body text under a sixth-level heading.

        ## A second-level heading with `code`, **bold** and a title long enough to wrap onto a second line

        Setext headings
        ===============

        Also supported
        --------------
        """,
    )

    static let links = CatalogSample(
        id: "links",
        title: "Links",
        systemImage: "link",
        summary: "Inline, reference and autolinks, and links carrying other styles.",
        markdown: """
        An [inline link](https://example.com), a [reference link][ref], and an autolink <https://example.com/a/rather/long/path?with=query&and=more>.

        Links carry other styles: [**bold link**](https://example.com), [*italic link*](https://example.com), [`code link`](https://example.com).

        A bare URL in text: https://github.com/Lakr233/MarkdownView

        [ref]: https://example.com
        """,
    )

    static let lists = CatalogSample(
        id: "lists",
        title: "Lists",
        systemImage: "list.bullet",
        summary: "Ordered, unordered and nested lists, and list items with several paragraphs.",
        markdown: """
        - First bullet
        - Second bullet, long enough to wrap onto the next line so the hanging indent is visible against the marker
        - Third bullet
          - Nested bullet
            - Third level bullet
              - Fourth level bullet

        1. First ordered item
        2. Second ordered item
           1. Nested ordered item
           2. Another nested item
        3. Third ordered item

        8. A list that starts at eight
        9. Nine
        10. Ten — the marker gets wider
        11. Eleven

        - A list item with two paragraphs.

          The second paragraph belongs to the same item.
        - A list item holding a code block:

          ```sh
          swift build
          ```
        """,
    )

    static let tasks = CatalogSample(
        id: "tasks",
        title: "Task Lists",
        systemImage: "checklist",
        summary: "Checked and unchecked items, nested tasks.",
        markdown: """
        - [x] Parse the document
        - [x] Build the attributed string
        - [ ] Draw the table
          - [x] Header row
          - [ ] Sorting
        - [ ] A task long enough to wrap onto a second line, to show how the checkbox aligns with the first line of text
        """,
    )

    static let blockquotes = CatalogSample(
        id: "blockquotes",
        title: "Blockquotes",
        systemImage: "text.quote",
        summary: "Quotes, nested quotes, and quotes holding other blocks.",
        markdown: """
        > A one-line quote.

        > A quote with **inline styles**, `code` and a [link](https://example.com), long enough to wrap so the bar runs alongside several lines.
        >
        > A second paragraph inside the same quote.

        Text between two quotes, which must not share a bar.

        > Outer quote
        > > Nested quote
        > > > Third level

        > A quote holding a list:
        >
        > - one
        > - two
        >
        > and a code block:
        >
        > ```js
        > console.log("quoted")
        > ```
        """,
    )

    static let codeBlocks = CatalogSample(
        id: "code-blocks",
        title: "Code Blocks",
        systemImage: "chevron.left.forwardslash.chevron.right",
        summary: "Highlighted languages, a plain block, and a line too long to wrap.",
        markdown: """
        ```swift
        import SwiftUI

        /// A view that greets someone.
        struct Greeting: View {
            let name: String
            @State private var count = 0

            var body: some View {
                Button("Hello, \\(name)! (\\(count))") {
                    count += 1
                }
            }
        }
        ```

        ```python
        def fibonacci(n: int) -> list[int]:
            # Returns the first n numbers.
            values = [0, 1]
            while len(values) < n:
                values.append(values[-1] + values[-2])
            return values[:n]
        ```

        ```json
        { "name": "MarkdownView", "stars": 1024, "tags": ["swift", "markdown"], "archived": false }
        ```

        ```
        A plain fenced block without a language.
        ```

        ```typescript
        export const veryLongLine = (input: ReadonlyArray<number>): number => input.filter((value) => value % 2 === 0).map((value) => value * 2).reduce((sum, value) => sum + value, 0)
        ```

            An indented code block.
        """,
    )

    static let tables = CatalogSample(
        id: "tables",
        title: "Tables",
        systemImage: "tablecells",
        summary: "Alignment, wrapping cells, inline styles in cells and a long table.",
        markdown: """
        | Feature | Status | Comment |
        |---------|--------|---------|
        | Bold    | ✅     | N/A     |
        | Italic  | ✅     | ---     |
        | Code    | ✅     | 1145141919810 |

        | Left aligned | Centered | Right aligned |
        | :----------- | :------: | ------------: |
        | short | mid | 1 |
        | a considerably longer cell that has to wrap | **bold** and `code` | 1145141919810 |
        | 中文单元格内容 | [link](https://example.com) | -42 |

        | Rank | Language | Stars | Notes |
        | ---: | :------- | ----: | :---- |
        | 1 | Swift | 67,800 | `async`/`await` |
        | 2 | Rust | 98,100 | [rust-lang.org](https://www.rust-lang.org) |
        | 3 | Go | 123,000 | 中文社区活跃 |
        | 4 | Kotlin | 49,300 | |
        | 5 | TypeScript | 101,000 | **typed** JavaScript |
        | 6 | Zig | 35,200 | `comptime` |
        | 7 | Python | 63,400 | 日本語のドキュメント |
        | 8 | C | 9,800 | |
        | 9 | Haskell | 3,000 | *lazy* |
        | 10 | Elixir | 24,100 | BEAM |
        | 11 | Dart | 10,300 | Flutter |
        | 12 | Julia | 45,600 | 科学计算 |

        | A | wide | table | with | many | columns | that | should | scroll | sideways | instead | of | squeezing |
        |---|------|-------|------|------|---------|------|--------|--------|----------|---------|----|-----------|
        | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
        """,
    )

    static let math = CatalogSample(
        id: "math",
        title: "Math",
        systemImage: "function",
        summary: "Inline and display LaTeX.",
        markdown: """
        Inline math sits on the baseline: $E = mc^2$, and $\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}$ in the middle of a sentence.

        $$
        \\int_{0}^{\\infty} e^{-x^2} \\, dx = \\frac{\\sqrt{\\pi}}{2}
        $$

        $$
        \\mathbf{A} = \\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}, \\quad \\det \\mathbf{A} = ad - bc
        $$
        """,
    )

    static let thematicBreaks = CatalogSample(
        id: "thematic-breaks",
        title: "Thematic Breaks",
        systemImage: "minus",
        summary: "Horizontal rules between paragraphs.",
        markdown: """
        Text above the rule.

        ---

        Text between two rules.

        ***

        Text below the rule.
        """,
    )

    static let narrow = CatalogSample(
        id: "narrow",
        title: "Long Tokens",
        systemImage: "arrow.left.and.right",
        summary: "Unbreakable tokens and long URLs; pick a narrow width in the toolbar.",
        markdown: """
        A very long unbreakable token: `supercalifragilisticexpialidocious_token_1145141919810_and_then_some`.

        A long URL: https://example.com/a/very/long/path/that/keeps/going/and/going/without/any/spaces/to/break/at

        Pneumonoultramicroscopicsilicovolcanoconiosis is a long word too.
        """,
    )

    static let multilingual = CatalogSample(
        id: "multilingual",
        title: "Multilingual",
        systemImage: "globe",
        summary: "CJK, emoji, right-to-left text and mixed scripts.",
        markdown: """
        ## 中文排版

        中文段落的行高与标点挤压需要单独检查。这是一段足够长、会自动换行的中文文本，里面混有 English words、`代码` 和 **加粗** 以及 *斜体*。

        ## 日本語

        日本語のかなと漢字が混ざった文章です。句読点の位置も確認します。

        ## 한국어

        한국어 문장도 줄바꿈이 자연스러워야 합니다.

        ## العربية

        هذا نص عربي يُكتب من اليمين إلى اليسار.

        ## Emoji

        🎉 🚀 👩‍💻 🇯🇵 ❤️‍🔥 — emoji in a sentence, and a list:

        - 🍎 Apple
        - 🍊 Orange
        """,
    )

    static let nesting = CatalogSample(
        id: "nesting",
        title: "Deep Nesting",
        systemImage: "list.bullet.indent",
        summary: "Lists inside quotes inside lists, and code inside both.",
        markdown: """
        1. A top-level step
           > A quote inside the step
           > - with a list
           >   - and a nested item
        2. Another step with code:
           ```bash
           echo "nested in a list"
           ```
           | in | a | list |
           |----|---|------|
           | 1  | 2 | 3    |
        3. Final step
        """,
    )

    static let everything = CatalogSample(
        id: "everything",
        title: "Everything",
        systemImage: "doc.richtext",
        summary: "Every sample on one page, in sidebar order.",
        markdown: [
            paragraphs, inlineStyles, headings, links, lists, tasks,
            blockquotes, codeBlocks, tables, math, thematicBreaks,
        ]
        .map { "# \($0.title)\n\n\($0.markdown)" }
        .joined(separator: "\n\n---\n\n"),
    )
}
