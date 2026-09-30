import MarkdownParser
import Testing

struct ParserRegressionTests {
    @Test("Math placeholder next to a code span stays separate")
    func mathPlaceholderNextToCodeSpanStaysSeparate() {
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

    @Test("Adjacent math placeholders stay separate")
    func adjacentMathPlaceholdersStaySeparate() {
        let result = MarkdownParser().parse("$$a$$$$b$$")

        #expect(mathContents(in: allInlines(in: result.document)) == ["a", "b"])
    }

    @Test("Backtick runs do not pair across paragraphs")
    func backtickRunsDoNotPairAcrossParagraphs() {
        let result = MarkdownParser().parse("Press ` to open.\n\n$$x^2$$\n\nRun `ls`.")
        let inlines = allInlines(in: result.document)

        #expect(mathContents(in: inlines) == ["x^2"])
        #expect(inlines.contains(.code("ls")))
    }

    @Test("Fenced code containing blank lines keeps math source")
    func fencedCodeWithBlankLinesKeepsMathSource() {
        let markdown = "```\n`\n\n$$x$$\n```"
        let result = MarkdownParser().parse(markdown)

        guard case let .codeBlock(_, content) = result.document.first else {
            Issue.record("Expected a code block")
            return
        }
        #expect(content == "`\n\n$$x$$\n")
    }

    @Test("Nested lists mixing task and plain items stay homogeneous")
    func nestedListsMixingTaskAndPlainItemsStayHomogeneous() {
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

    @Test("Blockquote inside a list inside a blockquote keeps its text")
    func blockquoteInsideListInsideBlockquoteKeepsText() {
        let result = MarkdownParser().parse("> - a\n>\n>   > b")
        let inlines = allInlines(in: result.document)

        #expect(inlines.contains(.text("a")))
        #expect(inlines.contains(.text("b")))
    }

    @Test("Table inside a list inside a blockquote keeps its cells")
    func tableInsideListInsideBlockquoteKeepsCells() {
        let result = MarkdownParser().parse("> - a\n>\n>   | h |\n>   |---|\n>   | c |")
        let inlines = allInlines(in: result.document)

        #expect(inlines.contains(.text("h")))
        #expect(inlines.contains(.text("c")))
    }

    @Test("Block ranges handle CRLF line endings")
    func blockRangesHandleCRLFLineEndings() {
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
