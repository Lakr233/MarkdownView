import MarkdownParser
import XCTest

final class MathPlaceholderRecoveryTests: XCTestCase {
    func testInlineMathInsideStrongNodeIsRecovered() {
        let markdown = "**Conclusion: shell mass \\\\(M_s\\\\) remains centered.**"
        let result = MarkdownParser().parse(markdown)

        XCTAssertFalse(containsMathPlaceholderCode(in: result.document))
        XCTAssertTrue(containsMathNode(in: result.document))
    }

    func testInlineMathInsideEmphasisNodeIsRecovered() {
        let markdown = "_Inline math \\\\(x+y\\\\) should render._"
        let result = MarkdownParser().parse(markdown)

        XCTAssertFalse(containsMathPlaceholderCode(in: result.document))
        XCTAssertTrue(containsMathNode(in: result.document))
    }

    func testInlineMathInsideStrikethroughNodeIsRecovered() {
        let markdown = "~~Deprecated \\\\(x_0\\\\) notation~~"
        let result = MarkdownParser().parse(markdown)

        XCTAssertFalse(containsMathPlaceholderCode(in: result.document))
        XCTAssertTrue(containsMathNode(in: result.document))
    }

    func testInlineMathInsideLinkLabelIsRecovered() {
        let markdown = "[equation \\\\(E=mc^2\\\\)](https://example.com)"
        let result = MarkdownParser().parse(markdown)

        XCTAssertFalse(containsMathPlaceholderCode(in: result.document))
        XCTAssertTrue(containsMathNode(in: result.document))
    }

    func testInlineMathInsideNestedInlineNodesIsRecovered() {
        let markdown = "_See **\\(a^2+b^2=c^2\\)** for the proof._"
        let result = MarkdownParser().parse(markdown)

        XCTAssertFalse(containsMathPlaceholderCode(in: result.document))
        XCTAssertTrue(containsMathNode(in: result.document))
    }

    func testInlineMathInsideTableCellNestedStrongNodeIsRecovered() {
        let markdown = """
        | Case | Value |
        | --- | --- |
        | A | **\\(M_s\\)** |
        """
        let result = MarkdownParser().parse(markdown)

        XCTAssertFalse(containsMathPlaceholderCode(in: result.document))
        XCTAssertTrue(containsMathNode(in: result.document))
    }
}

private func containsMathPlaceholderCode(in blocks: [MarkdownBlockNode]) -> Bool {
    blocks.contains { block in
        switch block {
        case let .blockquote(children):
            containsMathPlaceholderCode(in: children)
        case let .bulletedList(_, items):
            items.contains { containsMathPlaceholderCode(in: $0.children) }
        case let .numberedList(_, _, items):
            items.contains { containsMathPlaceholderCode(in: $0.children) }
        case let .taskList(_, items):
            items.contains { containsMathPlaceholderCode(in: $0.children) }
        case let .paragraph(content), let .heading(_, content):
            containsMathPlaceholderCode(in: content)
        case let .table(_, rows):
            rows.contains { row in
                row.cells.contains { containsMathPlaceholderCode(in: $0.content) }
            }
        case .codeBlock, .thematicBreak:
            false
        }
    }
}

private func containsMathPlaceholderCode(in nodes: [MarkdownInlineNode]) -> Bool {
    nodes.contains { node in
        switch node {
        case let .code(content):
            MarkdownParser.typeForReplacementText(content) == .math
        case let .emphasis(children), let .strong(children), let .strikethrough(children):
            containsMathPlaceholderCode(in: children)
        case let .link(_, children), let .image(_, children):
            containsMathPlaceholderCode(in: children)
        default:
            false
        }
    }
}

private func containsMathNode(in blocks: [MarkdownBlockNode]) -> Bool {
    blocks.contains { block in
        switch block {
        case let .blockquote(children):
            containsMathNode(in: children)
        case let .bulletedList(_, items):
            items.contains { containsMathNode(in: $0.children) }
        case let .numberedList(_, _, items):
            items.contains { containsMathNode(in: $0.children) }
        case let .taskList(_, items):
            items.contains { containsMathNode(in: $0.children) }
        case let .paragraph(content), let .heading(_, content):
            containsMathNode(in: content)
        case let .table(_, rows):
            rows.contains { row in
                row.cells.contains { containsMathNode(in: $0.content) }
            }
        case .codeBlock, .thematicBreak:
            false
        }
    }
}

private func containsMathNode(in nodes: [MarkdownInlineNode]) -> Bool {
    nodes.contains { node in
        switch node {
        case .math:
            true
        case let .emphasis(children), let .strong(children), let .strikethrough(children):
            containsMathNode(in: children)
        case let .link(_, children), let .image(_, children):
            containsMathNode(in: children)
        default:
            false
        }
    }
}
