import MarkdownParser
import Testing

struct StreamingTailTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let markdown: String
        let repaired: String

        init(_ markdown: String, _ repaired: String) {
            self.markdown = markdown
            self.repaired = repaired
        }

        var testDescription: String {
            markdown.debugDescription
        }
    }

    private static func repaired(_ markdown: String) -> String {
        MarkdownParser.StreamingTail(closing: markdown).applied(to: markdown)
    }

    // MARK: - What gets closed

    static let danglingMarkers: [Case] = [
        .init("para\n-", "para\n"),
        .init("para\n\n-", "para\n\n"),
        .init("para\n\n- item\n- ", "para\n\n- item\n"),
        .init("para\n\n*", "para\n\n"),
        .init("para\n\n+", "para\n\n"),
        .init("para\n\n1.", "para\n\n"),
        .init("1. one\n2", "1. one\n"),
        .init("para\n\n#", "para\n\n"),
        .init("para\n\n### ", "para\n\n"),
        .init("para\n\n>", "para\n\n"),
        .init("line one\n==", "line one\n"),
        .init("line one\n---", "line one\n"),
        .init("para\n\n- [ ]", "para\n\n"),
        .init("Hello **", "Hello"),
        .init("**bold** and **", "**bold** and"),
        .init("use `", "use"),
        .init("para\n\n[", "para\n\n"),
        .init("trail \\", "trail"),
        .init("x <di", "x"),
        .init("x </sp", "x"),
        .init("x <a href=\"ht", "x"),
        .init("x <https://exa", "x"),
        .init("Tom &amp", "Tom"),
    ]

    @Test(arguments: danglingMarkers)
    func `A dangling marker is held back`(_ testCase: Case) {
        #expect(Self.repaired(testCase.markdown) == testCase.repaired)
    }

    static let fences: [Case] = [
        .init("Intro\n\n```sw", "Intro\n\n"),
        .init("Intro\n\n- ```py", "Intro\n\n"),
        .init("```swift\nlet x = 1\n``", "```swift\nlet x = 1\n"),
        .init("~~~\nlet x = 1\n~", "~~~\nlet x = 1\n"),
        .init("```swift\nlet x = 1\n", "```swift\nlet x = 1\n"),
        .init("```swift\nlet x = **1", "```swift\nlet x = **1"),
        .init("```sw\n", "```sw\n"),
    ]

    @Test(arguments: fences)
    func `A fence is held back only while its line is partial`(_ testCase: Case) {
        #expect(Self.repaired(testCase.markdown) == testCase.repaired)
    }

    static let inlines: [Case] = [
        .init("Hello **bold", "Hello **bold**"),
        .init("Hello **bold ", "Hello **bold**"),
        .init("Hello *it", "Hello *it*"),
        .init("Hello _it", "Hello _it_"),
        .init("__init", "__init__"),
        .init("***both", "***both***"),
        .init("**bold and *nested", "**bold and *nested***"),
        .init("**bold*", "**bold**"),
        .init("**Note:** this is *fine", "**Note:** this is *fine*"),
        .init("a ~~strike", "a ~~strike~~"),
        .init("use `code", "use `code`"),
        .init("use ``a ` b", "use ``a ` b``"),
        .init("Hello `a` and `b", "Hello `a` and `b`"),
        .init("**see `code", "**see `code`**"),
        .init("> quote **bo", "> quote **bo**"),
        .init("- item one\n- item **tw", "- item one\n- item **tw**"),
        .init("中文**粗体", "中文**粗体**"),
        .init("emoji 😀**bo", "emoji 😀**bo**"),
        .init("## Title **bo", "## Title **bo**"),
    ]

    @Test(arguments: inlines)
    func `Emphasis and code spans on the last line are closed`(_ testCase: Case) {
        #expect(Self.repaired(testCase.markdown) == testCase.repaired)
    }

    static let links: [Case] = [
        .init("see [docs](https://exa", "see [docs](https://exa)"),
        .init("see [docs](https://example.com/a_(b", "see [docs](https://example.com/a_(b))"),
        .init("[a](<http://x", "[a](<http://x>)"),
        .init("[a](http://x \"ti", "[a](http://x \"ti\")"),
        .init("**see [docs](https://exa", "**see [docs](https://exa)**"),
        .init("an ![img](http://x", "an"),
        .init("an ![img", "an"),
        .init("an ![img]", "an"),
    ]

    @Test(arguments: links)
    func `An unfinished link is closed and an unfinished image dropped`(_ testCase: Case) {
        #expect(Self.repaired(testCase.markdown) == testCase.repaired)
    }

    static let tables: [Case] = [
        .init("| a | b |\n", "| a | b |\n| --- | --- |"),
        .init("| a | b |\n| --", "| a | b |\n| --- | --- |"),
        .init("| a | b |\n|", "| a | b |\n| --- | --- |"),
        .init("## T\n| a |\n", "## T\n| a |\n| --- |"),
        .init("| a | b |\n|---|---|\n| 1 | **x", "| a | b |\n|---|---|\n| 1 | **x**"),
        .init("| a | b |\n|---|---|\n", "| a | b |\n|---|---|\n"),
        .init("text\n| a |\n", "text\n| a |\n"),
    ]

    @Test(arguments: tables)
    func `A table header gets its delimiter row early`(_ testCase: Case) {
        #expect(Self.repaired(testCase.markdown) == testCase.repaired)
    }

    @Test
    func `Repaired markdown parses into the shape it is heading for`() {
        let parser = MarkdownParser()
        #expect(parser.parse("Hello **bold", isStreaming: true).document == [
            .paragraph(content: [.text("Hello "), .strong(children: [.text("bold")])]),
        ])
        #expect(parser.parse("para\n-", isStreaming: true).document == [
            .paragraph(content: [.text("para")]),
        ])
        #expect(parser.parse("Intro\n\n```sw", isStreaming: true).document == [
            .paragraph(content: [.text("Intro")]),
        ])
        guard case .table = parser.parse("| a | b |\n| --", isStreaming: true).document.first else {
            Issue.record("Expected a table")
            return
        }
    }

    // MARK: - What is left alone

    static let untouched: [String] = [
        "snake_case",
        "snake_case_name and more",
        "2*3",
        "2*3 = 6 and 2 * 3",
        "x**2 and",
        "rm *.txt",
        "rm *.txt then more",
        "a ** b",
        "price $5 and $10",
        "$5 … $10",
        "range 20~25",
        "see [1]",
        "see [1] and more",
        "see [docs",
        "a < b",
        "a < b and",
        "if a <b then",
        "Click <div cla",
        "AT&T",
        "text 1.",
        "Press ` to open",
        "first *line\nsecond line",
        "Hello **bold\n",
        "## Ti",
        "| a | b",
        "where $x *y",
        "math $$\\frac{a}{",
        "$$\nx_1 + **y_2",
        "\\(x^2 *y",
        "```swift\nlet a = **b",
        "```\n- ",
        "para\n\n    code **x",
        "    ```\n    code **x",
        "Done.",
        "",
    ]

    @Test(arguments: untouched)
    func `Text that closes nothing is left alone`(_ markdown: String) {
        let tail = MarkdownParser.StreamingTail(closing: markdown)
        #expect(tail == .init(keptLength: markdown.utf8.count, suffix: ""))
        #expect(Self.repaired(markdown) == markdown)
    }

    @Test
    func `Not streaming parses exactly as before`() {
        let parser = MarkdownParser()
        for markdown in Self.danglingMarkers.map(\.markdown) + Self.inlines.map(\.markdown) {
            #expect(parser.parse(markdown, isStreaming: false).document == parser.parse(markdown).document)
        }
    }

    @Test
    func `A nested list item is not mistaken for indented code`() {
        #expect(Self.repaired("- a\n\n    - b **c") == "- a\n\n    - b **c**")
    }
}
