import MarkdownParser
import Testing

struct MathPreprocessingTests {
    @Test("Inline dollar math splits text nodes")
    func inlineDollarMathSplitsTextNodes() throws {
        let result = MarkdownParser().parse("Before $x+y$ after")
        let paragraph = try #require(firstParagraph(in: result.document))

        #expect(paragraph.count == 3)
        #expect(paragraph.first == .text("Before "))
        #expect(paragraph.last == .text(" after"))

        guard case let .math(content, replacementIdentifier) = paragraph[1] else {
            Issue.record("Expected middle inline node to be math")
            return
        }

        #expect(content == "x+y")
        #expect(replacementIdentifier == MarkdownParser.replacementText(for: .math, identifier: "0"))
    }

    @Test("Fenced code blocks preserve math source text")
    func fencedCodeBlocksPreserveMathSourceText() throws {
        let markdown = """
        ```latex
        $$x+y$$
        ```
        """

        let result = MarkdownParser().parse(markdown)
        let codeBlock = try #require(firstCodeBlock(in: result.document))

        #expect(codeBlock.content == "$$x+y$$\n")
        #expect(!codeBlock.content.contains("md://content"))
    }
}

private func firstParagraph(in blocks: [MarkdownBlockNode]) -> [MarkdownInlineNode]? {
    for block in blocks {
        if case let .paragraph(content) = block {
            return content
        }
    }
    return nil
}

private func firstCodeBlock(in blocks: [MarkdownBlockNode]) -> (language: String?, content: String)? {
    for block in blocks {
        if case let .codeBlock(language, content) = block {
            return (language, content)
        }
    }
    return nil
}
