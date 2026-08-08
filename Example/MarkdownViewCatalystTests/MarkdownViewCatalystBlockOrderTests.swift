import MarkdownParser
@testable import MarkdownView
import SwiftUI
import Testing

#if canImport(UIKit)
    import UIKit

    private let demoDocument = """
    # MarkdownView

    This is a **demo** of the `MarkdownView` SwiftUI component. Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.

    ## Inline Styles

    - Supports **bold**, *italic*, ***bold italic***, ~~strikethrough~~ and `inline code`
    - [Links](https://example.com), autolinks like <https://example.com>, and [reference links][ref]
    - Escapes: \\*not italic\\*, entities: &copy; &amp; &rarr;
    - A very long unbreakable token that stresses narrow layouts: `supercalifragilisticexpialidocious_token_1145141919810`
    - Emoji and CJK: 🎉 中文排版、日本語のかな、한국어 混排

    [ref]: https://example.com

    ## Headings

    ### Level Three Heading

    #### Level Four Heading With A Fairly Long Title That Wraps When Narrow

    ##### Level Five

    ## Lists

    1. First ordered item
    2. Second ordered item
       1. Nested ordered item
       2. Another nested item
    3. Third ordered item

    - Bulleted item
      - Nested bullet with a long sentence so it wraps on narrow widths
        - Third level bullet
    - [ ] Unchecked task
    - [x] Checked task

    ## Code Example

    ```swift
    struct HelloWorld {
        func greet() {
            print("Hello, World!")
        }
    }
    ```

    A code block with long lines that must scroll horizontally instead of wrapping:

    ```python
    def compute(values: list[int]) -> int:
        return sum(value * 2 for value in values if value % 2 == 0 and value > 0 and value < 1000)
    ```

    ```
    plain fenced block without a language
    ```

    ## Math Support

    Inline math: $E = mc^2$, and another one $\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}$.

    Display math:

    $$
    \\int_{0}^{\\infty} e^{-x^2} \\, dx = \\frac{\\sqrt{\\pi}}{2}
    $$

    ## Tables

    | Feature | Status | Comment |
    |---------|--------|--------|
    | Bold    | ✅     | N/A     |
    | Italic  | ✅     | ---     |
    | Code    | ✅     | 1145141919810     |

    Alignment and wrapping:

    | Left aligned | Centered | Right aligned |
    | :----------- | :------: | ------------: |
    | short | mid | 1 |
    | a considerably longer cell that has to wrap | **bold** and `code` | 1145141919810 |
    | 中文单元格内容 | [link](https://example.com) | -42 |

    ## Blockquotes

    > This is a blockquote.
    > It can span multiple lines.

    > A blockquote with **inline styles**, `code`, and a [link](https://example.com)
    > plus a second paragraph that keeps wrapping when the window gets narrow.

    ## Thematic Breaks

    ---

    *Thank you for using MarkdownView!*
    """

    struct MarkdownViewCatalystBlockOrderTests {
        @MainActor
        @Test("Hosted markdown keeps blocks ordered while the window narrows")
        func hostedWindowKeepsBlocksOrdered() throws {
            let window = UIWindow(frame: .init(x: 0, y: 0, width: 800, height: 600))
            let host = UIHostingController(
                rootView: ScrollView { MarkdownView(demoDocument).padding() }
            )
            window.rootViewController = host
            window.isHidden = false
            window.layoutIfNeeded()

            let view = try #require(firstMarkdownTextView(in: window))

            for width in stride(from: 760.0 as CGFloat, through: 200, by: -40) {
                window.frame = .init(x: 0, y: 0, width: width, height: 600)
                window.layoutIfNeeded()
                host.view.layoutIfNeeded()
                expectOrderedBlocks(in: view, context: "window width \(width)")
            }
        }

        @MainActor
        @Test("Narrow layout keeps every block below the previous block", arguments: [
            180.0 as CGFloat, 220, 260, 320, 420,
        ])
        func narrowLayoutKeepsBlocksOrdered(width: CGFloat) {
            let view = MarkdownTextView()
            view.setContentImmediately(MarkdownContent(
                parserResult: MarkdownParser().parse(demoDocument),
                theme: .default
            ))
            let size = view.boundingSize(for: width)
            view.frame = .init(x: 0, y: 0, width: width, height: size.height)
            view.setNeedsLayout()
            view.layoutIfNeeded()

            expectOrderedBlocks(in: view, context: "width \(width)")
        }
    }

    @MainActor
    private func firstMarkdownTextView(in view: UIView) -> MarkdownTextView? {
        var queue: [UIView] = [view]
        while !queue.isEmpty {
            let next = queue.removeFirst()
            if let match = next as? MarkdownTextView { return match }
            queue.append(contentsOf: next.subviews)
        }
        return nil
    }

    @MainActor
    private func expectOrderedBlocks(
        in view: MarkdownTextView,
        context: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let boxes = view.verticalLayoutBoxes()
        for index in boxes.indices.dropFirst() {
            let previous = boxes[index - 1]
            let current = boxes[index]
            #expect(
                current.frame.minY >= previous.frame.maxY - 0.5,
                "\(current.label) at \(current.frame) overlaps \(previous.label) at \(previous.frame) — \(context)",
                sourceLocation: sourceLocation
            )
        }
    }
#endif
