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
            return containsMathPlaceholderCode(in: children)
        case let .bulletedList(_, items):
            return items.contains { containsMathPlaceholderCode(in: $0.children) }
        case let .numberedList(_, _, items):
            return items.contains { containsMathPlaceholderCode(in: $0.children) }
        case let .taskList(_, items):
            return items.contains { containsMathPlaceholderCode(in: $0.children) }
        case let .paragraph(content), let .heading(_, content):
            return containsMathPlaceholderCode(in: content)
        case let .table(_, rows):
            return rows.contains { row in
                row.cells.contains { containsMathPlaceholderCode(in: $0.content) }
            }
        case .codeBlock, .thematicBreak:
            return false
        }
    }
}

private func containsMathPlaceholderCode(in nodes: [MarkdownInlineNode]) -> Bool {
    nodes.contains { node in
        switch node {
        case let .code(content):
            return MarkdownParser.typeForReplacementText(content) == .math
        case let .emphasis(children), let .strong(children), let .strikethrough(children):
            return containsMathPlaceholderCode(in: children)
        case let .link(_, children), let .image(_, children):
            return containsMathPlaceholderCode(in: children)
        default:
            return false
        }
    }
}

private func containsMathNode(in blocks: [MarkdownBlockNode]) -> Bool {
    blocks.contains { block in
        switch block {
        case let .blockquote(children):
            return containsMathNode(in: children)
        case let .bulletedList(_, items):
            return items.contains { containsMathNode(in: $0.children) }
        case let .numberedList(_, _, items):
            return items.contains { containsMathNode(in: $0.children) }
        case let .taskList(_, items):
            return items.contains { containsMathNode(in: $0.children) }
        case let .paragraph(content), let .heading(_, content):
            return containsMathNode(in: content)
        case let .table(_, rows):
            return rows.contains { row in
                row.cells.contains { containsMathNode(in: $0.content) }
            }
        case .codeBlock, .thematicBreak:
            return false
        }
    }
}

private func containsMathNode(in nodes: [MarkdownInlineNode]) -> Bool {
    nodes.contains { node in
        switch node {
        case .math(_, _):
            return true
        case let .emphasis(children), let .strong(children), let .strikethrough(children):
            return containsMathNode(in: children)
        case let .link(_, children), let .image(_, children):
            return containsMathNode(in: children)
        default:
            return false
        }
    }
}
