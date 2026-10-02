import MarkdownParser
import Testing

struct ParserRegressionTests {
    @Test
    func `Math placeholder next to a code span stays separate`() {
        let result = MarkdownParser().parse("`a`$$x$$ and $$y$$`b`")
        let inlines = allInlines(in: result.document)

        #expect(inlines.contains(.code("a")))
        #expect(inlines.contains(.code("b")))
        #expect(mathContents(in: inlines) == ["x", "y"])
        #expect(!inlines.contains { node in
            guard case let .code(content) = node else { return false }
            return content.contains("md://")
        })
    }

    @Test
    func `Adjacent math placeholders stay separate`() {
        let result = MarkdownParser().parse("$$a$$$$b$$")

        #expect(mathContents(in: allInlines(in: result.document)) == ["a", "b"])
    }

    @Test
    func `Backtick runs do not pair across paragraphs`() {
        let result = MarkdownParser().parse("Press ` to open.\n\n$$x^2$$\n\nRun `ls`.")
        let inlines = allInlines(in: result.document)

        #expect(mathContents(in: inlines) == ["x^2"])
        #expect(inlines.contains(.code("ls")))
    }

    @Test
    func `Fenced code containing blank lines keeps math source`() {
        let markdown = "```\n`\n\n$$x$$\n```"
        let result = MarkdownParser().parse(markdown)

        guard case let .codeBlock(_, content) = result.document.first else {
            Issue.record("Expected a code block")
            return
        }
        #expect(content == "`\n\n$$x$$\n")
    }

    @Test
    func `A fence opened after a list marker still pairs across blank lines`() {
        let markdown = "- ```\n  a\n\n  b\n  ```\n\n$$x$$\n\n```\nc\n```"
        let result = MarkdownParser().parse(markdown)

        #expect(mathContents(in: allInlines(in: result.document)) == ["x"])
    }

    @Test
    func `A line of digits inside a code span does not end it`() {
        let result = MarkdownParser().parse("`a $$x$$\n2024\nb` then $$y$$")
        let inlines = allInlines(in: result.document)

        #expect(inlines.contains(.code("a $$x$$ 2024 b")))
        #expect(mathContents(in: inlines) == ["y"])
    }

    @Test
    func `Code blocks keep math beside a backtick exactly as written`() {
        let indented = MarkdownParser().parse("    `a`$$x$$")
        guard case let .codeBlock(_, indentedContent) = indented.document.first else {
            Issue.record("Expected an indented code block")
            return
        }
        #expect(indentedContent == "`a`$$x$$\n")

        let tilde = MarkdownParser().parse("~~~\n`a`$$x$$\n~~~")
        guard case let .codeBlock(_, tildeContent) = tilde.document.first else {
            Issue.record("Expected a tilde-fenced code block")
            return
        }
        #expect(tildeContent == "`a`$$x$$\n")
    }

    @Test
    func `An escaped backtick before math adds no space`() {
        let result = MarkdownParser().parse("\\`$$x$$")
        let inlines = allInlines(in: result.document)

        #expect(inlines.first == .text("`"))
        #expect(mathContents(in: inlines) == ["x"])
    }

    @Test
    func `Nested lists mixing task and plain items stay homogeneous`() {
        let result = MarkdownParser().parse("- a\n  - [ ] x\n  - y")

        guard case let .bulletedList(_, items) = result.document.first,
              let children = items.first?.children
        else {
            Issue.record("Expected an outer bulleted list")
            return
        }
        #expect(children.count == 3)
        guard children.count == 3 else { return }
        guard case let .taskList(_, taskItems) = children[1] else {
            Issue.record("Expected the nested task item as its own task list")
            return
        }
        guard case let .bulletedList(_, plainItems) = children[2] else {
            Issue.record("Expected the nested plain item as a bulleted list")
            return
        }
        #expect(taskItems.count == 1)
        #expect(plainItems.count == 1)
    }

    @Test
    func `Blockquote inside a list inside a blockquote keeps its text`() {
        let result = MarkdownParser().parse("> - a\n>\n>   > b")
        let inlines = allInlines(in: result.document)

        #expect(inlines.contains(.text("a")))
        #expect(inlines.contains(.text("b")))
    }

    @Test
    func `Table inside a list inside a blockquote keeps its cells`() {
        let result = MarkdownParser().parse("> - a\n>\n>   | h |\n>   |---|\n>   | c |")
        let inlines = allInlines(in: result.document)

        #expect(inlines.contains(.text("h")))
        #expect(inlines.contains(.text("c")))
    }

    @Test
    func `Blockquote lifted out of a list holds only paragraphs`() {
        let result = MarkdownParser().parse("1. step\n   > quote\n   > - a\n   >   - b")
        let quotes = result.document.compactMap { block -> [MarkdownBlockNode]? in
            guard case let .blockquote(children) = block else { return nil }
            return children
        }

        #expect(quotes.count == 1)
        #expect(quotes.flatMap(\.self).allSatisfy { child in
            guard case .paragraph = child else { return false }
            return true
        })
        #expect(allInlines(in: result.document).contains(.text("b")))
    }

    @Test
    func `Block ranges handle CRLF line endings`() {
        let markdown = "# a\r\n\r\nb\r\nc\r\n\r\nd"
        let ranges = MarkdownParser().parseBlockRange(markdown)

        #expect(ranges.map { String(markdown[$0.startIndex ..< $0.endIndex]) } == ["# a", "b\r\nc", "d"])
    }
}

private func allInlines(in blocks: [MarkdownBlockNode]) -> [MarkdownInlineNode] {
    blocks.flatMap { block -> [MarkdownInlineNode] in
        switch block {
        case let .paragraph(content), let .heading(_, content):
            allInlines(in: content)
        case let .blockquote(children):
            allInlines(in: children)
        case let .bulletedList(_, items), let .numberedList(_, _, items):
            items.flatMap { allInlines(in: $0.children) }
        case let .taskList(_, items):
            items.flatMap { allInlines(in: $0.children) }
        case let .table(_, rows):
            rows.flatMap { $0.cells.flatMap { allInlines(in: $0.content) } }
        case .codeBlock, .thematicBreak:
            []
        }
    }
}

private func allInlines(in nodes: [MarkdownInlineNode]) -> [MarkdownInlineNode] {
    nodes.flatMap { node -> [MarkdownInlineNode] in
        switch node {
        case let .emphasis(children), let .strong(children), let .strikethrough(children):
            [node] + allInlines(in: children)
        case let .link(_, children), let .image(_, children):
            [node] + allInlines(in: children)
        default:
            [node]
        }
    }
}

private func mathContents(in nodes: [MarkdownInlineNode]) -> [String] {
    nodes.compactMap { node in
        guard case let .math(content, _) = node else { return nil }
        return content
    }
}
