import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit

    private typealias TestContainerView = UIView
    private typealias TestScrollView = UIScrollView
#elseif canImport(AppKit)
    import AppKit

    private typealias TestContainerView = NSView
    private typealias TestScrollView = NSScrollView
#endif

struct MarkdownViewLayoutTests {
    @MainActor
    @Test("Table cells are reused across reconfiguration")
    func tableCellsAreReusedAcrossReconfiguration() {
        let manager = TableViewCellManager()
        let container = TestContainerView(frame: .init(x: 0, y: 0, width: 400, height: 400))

        manager.configureCells(
            for: [
                [makeText("A"), makeText("B")],
                [makeText("C"), makeText("D")],
            ],
            in: container,
            cellPadding: 10,
            maximumCellWidth: 180
        )

        let originalIdentifiers = manager.cells.map(ObjectIdentifier.init)

        manager.configureCells(
            for: [
                [makeText("AA"), makeText("BB")],
                [makeText("CC"), makeText("DD")],
            ],
            in: container,
            cellPadding: 10,
            maximumCellWidth: 180
        )

        #expect(manager.cells.count == 4)
        #expect(manager.cells.map(ObjectIdentifier.init) == originalIdentifiers)
    }

    @MainActor
    @Test("Table cells are trimmed when content shrinks")
    func tableCellsAreTrimmedWhenContentShrinks() {
        let manager = TableViewCellManager()
        let container = TestContainerView(frame: .init(x: 0, y: 0, width: 400, height: 400))

        manager.configureCells(
            for: [
                [makeText("A"), makeText("B")],
                [makeText("C"), makeText("D")],
            ],
            in: container,
            cellPadding: 10,
            maximumCellWidth: 180
        )

        manager.configureCells(
            for: [[makeText("Only one")]],
            in: container,
            cellPadding: 10,
            maximumCellWidth: 180
        )

        #expect(manager.cells.count == 1)
        #expect(container.subviews.count == 1)
    }

    @MainActor
    @Test("Reused table cells refresh their width constraint")
    func reusedTableCellsRefreshTheirWidthConstraint() throws {
        let manager = TableViewCellManager()
        let container = TestContainerView(frame: .init(x: 0, y: 0, width: 400, height: 400))

        manager.configureCells(
            for: [[makeText("Wrapped content that needs width")]],
            in: container,
            cellPadding: 10,
            maximumCellWidth: 220
        )

        let cell = try #require(manager.cells.first)
        #expect(cell.preferredMaxLayoutWidth == 220)

        manager.configureCells(
            for: [[makeText("Wrapped content that needs width")]],
            in: container,
            cellPadding: 10,
            maximumCellWidth: 120
        )

        let reusedCell = try #require(manager.cells.first)
        #expect(reusedCell === cell)
        #expect(cell.preferredMaxLayoutWidth == 120)
    }

    @MainActor
    @Test("Table widths and heights follow row and column maxima")
    func tableWidthsAndHeightsFollowRowAndColumnMaxima() {
        let manager = TableViewCellManager()
        let container = TestContainerView(frame: .init(x: 0, y: 0, width: 400, height: 400))

        manager.configureCells(
            for: [
                [makeText("Short"), makeText("A much longer value")],
                [makeText("This cell is tallest\nbecause it wraps"), makeText("Mid")],
            ],
            in: container,
            cellPadding: 10,
            maximumCellWidth: 140
        )

        let cellSizes = manager.cellSizes
        let expectedWidths = [
            max(cellSizes[0].width, cellSizes[2].width),
            max(cellSizes[1].width, cellSizes[3].width),
        ]
        let expectedHeights = [
            max(cellSizes[0].height, cellSizes[1].height),
            max(cellSizes[2].height, cellSizes[3].height),
        ]

        #expect(manager.widths == expectedWidths)
        #expect(manager.heights == expectedHeights)
    }

    @MainActor
    @Test("Table content normalizes HTML line breaks")
    func tableContentNormalizesHTMLLineBreaks() {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 240, height: 120))
        tableView.setContents([[makeText("Line 1<br>Line 2")]])

        #expect(tableView.contents[0][0].string == "Line 1\nLine 2")
        #expect(tableView.attributedStringRepresentation().string.contains("Line 1\nLine 2"))
    }

    @MainActor
    @Test("Table grid matches scrollable content size")
    func tableGridMatchesScrollableContentSize() throws {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 140, height: 90))
        tableView.setTheme(.default)
        tableView.setContents([
            [makeText("Very long header"), makeText("Another very long header")],
            [makeText("Large content cell that should exceed the visible width"), makeText("Second column")],
        ])
        layout(view: tableView)

        let scrollView = try #require(extractScrollView(from: tableView))
        let gridView = try #require(extractGridView(from: scrollView))

        #expect(gridView.frame.size == tableView.intrinsicContentSize)
    }

    @MainActor
    @Test("Plain table surface passes selection through")
    func plainTableSurfacePassesSelectionThrough() {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 260, height: 120))
        tableView.setContents([
            [makeText("Plain header"), makeText("Value")],
            [makeText("Plain cell"), makeText("Another cell")],
        ])
        layout(view: tableView)

        #expect(tableView.interactionTarget(at: CGPoint(x: 24, y: 24)) == nil)
    }

    @MainActor
    @Test("Scrollable table surface remains interactive")
    func scrollableTableSurfaceRemainsInteractive() {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 80, height: 120))
        tableView.setContents([
            [makeText("A very long header"), makeText("Another very long header")],
            [makeText("A very long value"), makeText("Another very long value")],
        ])
        layout(view: tableView)

        #expect(tableView.interactionTarget(at: CGPoint(x: 24, y: 24)) != nil)
    }

    @MainActor
    @Test("Plain code surface passes selection through")
    func plainCodeSurfacePassesSelectionThrough() {
        let codeView = CodeView(frame: .init(x: 0, y: 0, width: 260, height: 160))
        codeView.theme = .default
        codeView.content = "let value = 1"
        layout(view: codeView)

        #expect(codeView.interactionTarget(at: CGPoint(x: 24, y: 80)) == nil)
    }

    @MainActor
    @Test("Code toolbar remains interactive")
    func codeToolbarRemainsInteractive() {
        let codeView = CodeView(frame: .init(x: 0, y: 0, width: 260, height: 160))
        codeView.theme = .default
        codeView.content = "let value = 1"
        layout(view: codeView)

        #expect(codeView.interactionTarget(at: CGPoint(x: 240, y: 20)) != nil)
    }

    @MainActor
    @Test("MarkdownTextView height grows as width shrinks")
    func markdownTextViewHeightGrowsAsWidthShrinks() {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 1)
        view.setMarkdownManually(preprocessedContent(for: """
        This is a long paragraph with enough words to wrap several times when the width becomes narrow.
        """))

        let wide = view.boundingSize(for: 320)
        let medium = view.boundingSize(for: 180)
        let narrow = view.boundingSize(for: 100)

        #expect(wide.height > 0)
        #expect(wide.height <= medium.height)
        #expect(medium.height <= narrow.height)
    }

    @MainActor
    @Test("MarkdownTextView reuses table context views")
    func markdownTextViewReusesTableContextViews() throws {
        let view = MarkdownTextView()

        view.setMarkdownManually(preprocessedContent(for: """
        | Name | Value |
        | --- | --- |
        | Alpha | One |
        """))
        let original = try #require(view.contextViews.first as? TableView)

        view.setMarkdownManually(preprocessedContent(for: """
        | Name | Value |
        | --- | --- |
        | Beta | Two |
        """))
        let updated = try #require(view.contextViews.first as? TableView)

        #expect(original === updated)
    }

    @MainActor
    @Test("Mixed CJK and RTL text gets stable CoreText language attributes")
    func mixedCJKAndRTLTextGetsStableCoreTextLanguageAttributes() {
        let context = MarkdownTextView.PreprocessedContent(
            blocks: [],
            rendered: [:],
            highlightMaps: [:],
            locale: Locale(identifier: "zh-Hans")
        )
        let rendered = MarkdownInlineNode
            .text("中文段落 日本語かな العربية")
            .render(theme: .default, context: context, viewProvider: .init())

        #expect(language(at: "中", in: rendered) == "zh-Hans")
        #expect(language(at: "日", in: rendered) == "ja")
        #expect(language(at: "か", in: rendered) == "ja")
        #expect(language(at: "ع", in: rendered) == "ar")
    }

    @MainActor
    @Test("Preprocessed content preserves explicit locale")
    func preprocessedContentPreservesExplicitLocale() {
        let content = MarkdownTextView.PreprocessedContent(
            parserResult: MarkdownParser().parse("中文と日本語かな"),
            theme: .default,
            locale: Locale(identifier: "ja")
        )

        #expect(content.locale.identifier == "ja")
    }

    @MainActor
    @Test("Multilingual markdown fixture parses preprocesses and renders")
    func multilingualMarkdownFixtureParsesPreprocessesAndRenders() throws {
        let markdownURL = try #require(Bundle.module.url(
            forResource: "MultilingualStress",
            withExtension: "md"
        ))
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        let parserResult = MarkdownParser().parse(markdown)
        let content = MarkdownTextView.PreprocessedContent(
            parserResult: parserResult,
            theme: .default,
            locale: Locale(identifier: "zh-Hans")
        )
        let view = MarkdownTextView()

        view.setMarkdownManually(content)
        let size = view.boundingSize(for: 320)

        #expect(content.blocks.count >= 5)
        #expect(content.blocks.contains { if case .table = $0 { true } else { false } })
        #expect(content.blocks.contains { if case .codeBlock = $0 { true } else { false } })
        #expect(view.contextViews.contains { $0 is TableView })
        #expect(view.contextViews.contains { $0 is CodeView })
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @MainActor
    @Test("MarkdownTextView reuses code context views")
    func markdownTextViewReusesCodeContextViews() throws {
        let view = MarkdownTextView()

        view.setMarkdownManually(preprocessedContent(for: """
        ```swift
        let value = 1
        ```
        """))
        let original = try #require(view.contextViews.first as? CodeView)

        view.setMarkdownManually(preprocessedContent(for: """
        ```swift
        let value = 2
        ```
        """))
        let updated = try #require(view.contextViews.first as? CodeView)

        #expect(original === updated)
    }

    @MainActor
    @Test("MarkdownTextView keeps root text hittable through plain table")
    func markdownTextViewKeepsRootTextHittableThroughPlainTable() throws {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 400)
        view.setMarkdownManually(preprocessedContent(for: """
        Before

        | Name | Value |
        | --- | --- |
        | Alpha | Beta |

        After
        """))

        let tableView = try #require(view.contextViews.first as? TableView)
        let probe = CGPoint(x: tableView.frame.midX, y: tableView.frame.midY)
        let overlayTarget = tableView.interactionTarget(at: tableView.convert(probe, from: view))
        let rootTarget = view.textView.hitTest(view.textView.convert(probe, from: view))

        #expect(overlayTarget == nil)
        #expect(rootTarget != nil)
    }

    @MainActor
    @Test("MarkdownTextView keeps root text hittable through plain code")
    func markdownTextViewKeepsRootTextHittableThroughPlainCode() throws {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 400)
        view.setMarkdownManually(preprocessedContent(for: """
        Before

        ```swift
        let value = 1
        ```

        After
        """))

        let codeView = try #require(view.contextViews.first as? CodeView)
        let probe = CGPoint(x: codeView.frame.midX, y: codeView.frame.midY)
        let overlayTarget = codeView.interactionTarget(at: codeView.convert(probe, from: view))
        let rootTarget = view.textView.hitTest(view.textView.convert(probe, from: view))

        #expect(overlayTarget == nil)
        #expect(rootTarget != nil)
    }
}

@MainActor
private func makeText(_ string: String) -> NSAttributedString {
    NSAttributedString(
        string: string,
        attributes: [
            .font: MarkdownTheme.default.fonts.body,
        ]
    )
}

@MainActor
private func preprocessedContent(for markdown: String) -> MarkdownTextView.PreprocessedContent {
    MarkdownTextView.PreprocessedContent(
        parserResult: MarkdownParser().parse(markdown),
        theme: .default
    )
}

@MainActor
private func layout(view: TableView) {
    #if canImport(UIKit)
        view.layoutIfNeeded()
    #elseif canImport(AppKit)
        view.layoutSubtreeIfNeeded()
    #endif
}

@MainActor
private func layout(view: CodeView) {
    #if canImport(UIKit)
        view.layoutIfNeeded()
    #elseif canImport(AppKit)
        view.layoutSubtreeIfNeeded()
    #endif
}

@MainActor
private func extractScrollView(from tableView: TableView) -> TestScrollView? {
    tableView.subviews.first { $0 is TestScrollView } as? TestScrollView
}

@MainActor
private func extractGridView(from scrollView: TestScrollView) -> GridView? {
    #if canImport(UIKit)
        scrollView.subviews.first { $0 is GridView } as? GridView
    #elseif canImport(AppKit)
        scrollView.documentView as? GridView
    #endif
}

private func language(at needle: String, in attributedString: NSAttributedString) -> String? {
    let range = (attributedString.string as NSString).range(of: needle)
    guard range.location != NSNotFound else { return nil }
    return attributedString.attribute(.coreTextLanguage, at: range.location, effectiveRange: nil) as? String
}
