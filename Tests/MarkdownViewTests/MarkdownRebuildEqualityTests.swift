import Litext
@testable import MarkdownView
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    /// A rebuild of unchanged content has to compare equal to the document it
    /// replaces, so the label keeps its layout, and a streamed edit typesets
    /// only from the block it touched. Markers, breaks and attachments are
    /// made anew on every rebuild, so they have to compare by value.
    @MainActor
    struct MarkdownRebuildEqualityTests {
        private nonisolated static let markdown = """
        Intro with `inline code` and $x^2$ math.

        - first item
        - second item
          1. nested one
          2. nested two
        - [x] done task

        ---

        ```swift
        let value = 1
        ```

        | a | b |
        | - | - |
        | 1 | 2 |
        """

        @Test(arguments: [
            "- first\n- second\n- third",
            "1. one\n2. two\n3. three",
            "- [ ] open\n- [x] done",
            "Before\n\n---\n\nAfter",
            "Run `swift test` now",
            "Math $x^2$ inline",
            "```swift\nlet value = 1\n```",
            "| a | b |\n| - | - |\n| 1 | 2 |",
            "- first item\n- second item\n  1. nested one\n  2. nested two\n- [x] done task",
            "- a\n  1. b\n  2. c",
            "Intro with `inline code` and $x^2$ math.",
            "Intro with $x^2$ math.",
            "Intro with $x^2$ math.\n\n- item",
            "Intro.\n\n```swift\nlet value = 1\n```\n\n| a | b |\n| - | - |\n| 1 | 2 |",
            "Intro.\n\n---\n\n```swift\nlet value = 1\n```",
            markdown,
        ])
        func `rebuilding unchanged content keeps the label's layout`(_ markdown: String) {
            let view = MarkdownTextView()
            view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
            view.setContentImmediately(MarkdownContent(markdown: markdown, theme: .default))
            let layout = view.textLabelView.textLayout
            view.setContentImmediately(MarkdownContent(markdown: markdown, theme: .default))
            #expect(view.textLabelView.textLayout === layout)
        }

        @Test
        func `a marker compares by what it draws`() {
            let owner = ObjectIdentifier(MarkdownTextView.self)
            let first = MarkLineDrawingAction(mark: .bullet(depth: 1), theme: .default, owner: owner) { _, _, _ in }
            let same = MarkLineDrawingAction(mark: .bullet(depth: 1), theme: .default, owner: owner) { _, _, _ in }
            let deeper = MarkLineDrawingAction(mark: .bullet(depth: 2), theme: .default, owner: owner) { _, _, _ in }
            var theme = MarkdownTheme.default
            theme.colors.body = .red
            let recolored = MarkLineDrawingAction(mark: .bullet(depth: 1), theme: theme, owner: owner) { _, _, _ in }
            #expect(first.isEqual(same))
            #expect(!first.isEqual(deeper))
            #expect(!first.isEqual(recolored))
        }
    }
#endif
