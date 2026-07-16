import MarkdownParser
@testable import MarkdownView
import SwiftUI
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
            metrics: testTableMetrics(maximumTextWidth: 180)
        )

        let originalIdentifiers = manager.cells.map(ObjectIdentifier.init)

        manager.configureCells(
            for: [
                [makeText("AA"), makeText("BB")],
                [makeText("CC"), makeText("DD")],
            ],
            in: container,
            metrics: testTableMetrics(maximumTextWidth: 180)
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
            metrics: testTableMetrics(maximumTextWidth: 180)
        )

        manager.configureCells(
            for: [[makeText("Only one")]],
            in: container,
            metrics: testTableMetrics(maximumTextWidth: 180)
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
            metrics: testTableMetrics(maximumTextWidth: 220)
        )

        let cell = try #require(manager.cells.first)
        #expect(cell.preferredMaxLayoutWidth == 220)

        manager.configureCells(
            for: [[makeText("Wrapped content that needs width")]],
            in: container,
            metrics: testTableMetrics(maximumTextWidth: 120)
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
            metrics: testTableMetrics(maximumTextWidth: 140)
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
    @Test("Table columns use native point width bounds and readable row heights")
    func tableColumnsUseNativePointBounds() throws {
        let manager = TableViewCellManager()
        let container = TestContainerView(frame: .init(x: 0, y: 0, width: 390, height: 400))
        let longToken = String(repeating: "unbroken", count: 80)

        manager.configureCells(
            for: [
                [makeText("A"), makeText(longToken)],
                [makeText(""), makeText("Value")],
            ],
            in: container,
            metrics: .compact
        )

        #expect(manager.widths.allSatisfy { (88 ... 280).contains($0) })
        #expect(manager.heights.allSatisfy { $0 >= 38 })
        #expect(manager.cells[1].preferredMaxLayoutWidth == 262)

        let paragraphStyle = try #require(
            manager.cells[1].attributedText.attribute(
                .paragraphStyle,
                at: 0,
                effectiveRange: nil
            ) as? NSParagraphStyle
        )
        #expect(paragraphStyle.lineBreakMode == .byWordWrapping)
        #expect(manager.cells[1].intrinsicContentSize.width <= 262)
    }

    @MainActor
    @Test("One to three short columns fill the table viewport")
    func shortTablesFillViewport() throws {
        for columnCount in 1 ... 3 {
            let tableView = TableView(frame: .init(x: 0, y: 0, width: 390, height: 120))
            let row = (0 ..< columnCount).map { makeText("C\($0)") }
            tableView.setContents([row, row])
            layout(view: tableView)

            let scrollView = try #require(extractScrollView(from: tableView))
            let gridView = try #require(extractGridView(from: scrollView))
            #expect(abs(gridView.frame.width - tableView.bounds.width) <= 0.5)
        }
    }

    @MainActor
    @Test("Five short columns remain horizontally scrollable")
    func wideTablesRemainHorizontallyScrollable() throws {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 320, height: 120))
        let row = (0 ..< 5).map { makeText("C\($0)") }
        tableView.setContents([row, row])
        layout(view: tableView)

        let scrollView = try #require(extractScrollView(from: tableView))
        let gridView = try #require(extractGridView(from: scrollView))
        #expect(gridView.frame.width > tableView.bounds.width)
    }

    @MainActor
    @Test("Table cells are top aligned")
    func tableCellsAreTopAligned() throws {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 320, height: 160))
        tableView.setContents([
            [makeText("Short"), makeText("First line\nSecond line")],
        ])
        layout(view: tableView)

        let scrollView = try #require(extractScrollView(from: tableView))
        let cells = extractTableCells(from: scrollView)
        #expect(cells.count == 2)
        #expect(abs(cells[0].frame.minY - cells[1].frame.minY) <= 0.5)
    }

    @MainActor
    @Test("Markdown column alignment reaches table headers and cells")
    func markdownColumnAlignmentReachesTableCells() throws {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 390, height: 240)
        view.setContentImmediately(preprocessedContent(for: """
        | Left | Center | Right |
        | :--- | :---: | ---: |
        | A | B | C |
        """))

        let tableView = try #require(view.contextViews.first as? TableView)
        #expect(tableView.columnAlignments == [.left, .center, .right])

        let scrollView = try #require(extractScrollView(from: tableView))
        let cells = extractTableCells(from: scrollView)
        #expect(cells.count == 6)
        #expect(paragraphAlignment(in: cells[0]) == .left)
        #expect(paragraphAlignment(in: cells[1]) == .center)
        #expect(paragraphAlignment(in: cells[2]) == .right)
        #expect(paragraphAlignment(in: cells[3]) == .left)
        #expect(paragraphAlignment(in: cells[4]) == .center)
        #expect(paragraphAlignment(in: cells[5]) == .right)
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
    @Test("Plain table surface routes selection to table cell")
    func plainTableSurfaceRoutesSelectionToTableCell() throws {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 260, height: 120))
        tableView.setContents([
            [makeText("Plain header"), makeText("Value")],
            [makeText("Plain cell"), makeText("Another cell")],
        ])
        layout(view: tableView)

        let target = try #require(tableView.interactionTarget(at: CGPoint(x: 24, y: 24)))

        #expect(target.isDescendant(of: tableView))
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
    @Test("Table forwards cell selection events")
    func tableForwardsCellSelectionEvents() throws {
        let tableView = TableView(frame: .init(x: 0, y: 0, width: 260, height: 120))
        let probe = TextSelectionProbe()
        tableView.textSelectionDelegate = probe
        tableView.setContents([
            [makeText("Plain header"), makeText("Value")],
            [makeText("Plain cell"), makeText("Another cell")],
        ])
        layout(view: tableView)

        let target = try #require(tableView.interactionTarget(at: CGPoint(x: 24, y: 24)) as? TextLabelView)
        let selection = NSRange(location: 0, length: 4)
        let dragLocation = CGPoint(x: 6, y: 8)

        tableView.textLabelView(target, didChangeSelection: selection)
        tableView.textLabelView(target, didDragSelectionAt: dragLocation)

        #expect(probe.changedLabel === target)
        #expect(probe.changedSelection == selection)
        #expect(probe.draggedLabel === target)
        #expect(probe.dragLocation == dragLocation)
    }

    @MainActor
    @Test("Plain code surface routes selection to code text")
    func plainCodeSurfaceRoutesSelectionToCodeText() throws {
        let codeView = CodeView(frame: .init(x: 0, y: 0, width: 260, height: 160))
        codeView.theme = .default
        codeView.content = "let value = 1"
        layout(view: codeView)

        let probe = codeView.convert(
            CGPoint(x: codeView.textView.bounds.midX, y: codeView.textView.bounds.midY),
            from: codeView.textView
        )
        let target = try #require(codeView.interactionTarget(at: probe))

        #expect(target === codeView.textView || target.isDescendant(of: codeView.textView))
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

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        @MainActor
        @Test("Code forwards vertical scroll events to its responder chain")
        func codeForwardsVerticalScrollEvents() throws {
            let container = ScrollWheelProbe(frame: .init(x: 0, y: 0, width: 260, height: 160))
            let codeView = CodeView(frame: container.bounds)
            codeView.theme = .default
            codeView.content = "let value = 1"
            container.addSubview(codeView)
            layout(view: codeView)

            codeView.scrollView.scrollWheel(with: try makeScrollWheelEvent(deltaY: 1))

            #expect(container.eventCount == 1)
        }
    #endif

    @MainActor
    @Test("MarkdownTextView height grows as width shrinks")
    func markdownTextViewHeightGrowsAsWidthShrinks() {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 1)
        view.setContentImmediately(preprocessedContent(for: """
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
    @Test("MarkdownView coordinator sizes representable to full content height")
    func markdownViewCoordinatorSizesRepresentableToFullContentHeight() async throws {
        var measuredHeight: CGFloat = 0
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 388, height: 925)
        let filler = Array(
            repeating: "This paragraph keeps the table below the first viewport so sizing must grow beyond the initial view height.",
            count: 18
        ).joined(separator: "\n\n")

        view.setContentImmediately(preprocessedContent(for: """
        \(filler)

        ```swift
        let value = 1
        ```

        | Feature | Status |
        | --- | --- |
        | Table | Visible |
        """))
        let tableView = try #require(view.contextViews.first { $0 is TableView } as? TableView)

        let coordinator = MarkdownViewCoordinator()
        coordinator.heightBinding = Binding(
            get: { measuredHeight },
            set: { measuredHeight = $0 }
        )

        let size = try #require(coordinator.sizeThatFits(
            ProposedViewSize(width: 388, height: nil),
            for: view
        ))
        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(size.width == 388)
        #expect(size.height > view.bounds.height)
        #expect(abs(measuredHeight - size.height) <= 0.5)

        view.frame = .init(x: 0, y: 0, width: size.width, height: size.height)
        layout(view: view)

        #expect(tableView.superview === view)
        #expect(tableView.frame.maxY <= view.bounds.maxY)
    }

    @MainActor
    @Test("MarkdownTextView reuses table context views")
    func markdownTextViewReusesTableContextViews() throws {
        let view = MarkdownTextView()

        view.setContentImmediately(preprocessedContent(for: """
        | Name | Value |
        | --- | --- |
        | Alpha | One |
        """))
        let original = try #require(view.contextViews.first as? TableView)

        view.setContentImmediately(preprocessedContent(for: """
        | Name | Value |
        | --- | --- |
        | Beta | Two |
        """))
        let updated = try #require(view.contextViews.first as? TableView)

        #expect(original === updated)
    }

    @MainActor
    @Test("MarkdownTextView connects table selection delegate")
    func markdownTextViewConnectsTableSelectionDelegate() throws {
        let view = MarkdownTextView()

        view.setContentImmediately(preprocessedContent(for: """
        | Name | Value |
        | --- | --- |
        | Alpha | One |
        """))

        let tableView = try #require(view.contextViews.first as? TableView)

        #expect(tableView.textSelectionDelegate === view)
    }

    @MainActor
    @Test("MarkdownTextView lays out table context views without drawing")
    func markdownTextViewLaysOutTableContextViewsWithoutDrawing() throws {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 400)

        view.setContentImmediately(preprocessedContent(for: """
        | Name | Value |
        | --- | --- |
        | Alpha | One |
        """))

        let tableView = try #require(view.contextViews.first as? TableView)
        layout(view: view)

        #expect(tableView.superview === view)
        #expect(tableView.frame.width == view.bounds.width)
        #expect(tableView.frame.height > 0)
    }

    @MainActor
    @Test("Mixed CJK and RTL text gets stable CoreText language attributes")
    func mixedCJKAndRTLTextGetsStableCoreTextLanguageAttributes() {
        let context = MarkdownContent(
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
        let content = MarkdownContent(
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
        let content = MarkdownContent(
            parserResult: parserResult,
            theme: .default,
            locale: Locale(identifier: "zh-Hans")
        )
        let view = MarkdownTextView()

        view.setContentImmediately(content)
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

        view.setContentImmediately(preprocessedContent(for: """
        ```swift
        let value = 1
        ```
        """))
        let original = try #require(view.contextViews.first as? CodeView)

        view.setContentImmediately(preprocessedContent(for: """
        ```swift
        let value = 2
        ```
        """))
        let updated = try #require(view.contextViews.first as? CodeView)

        #expect(original === updated)
    }

    @MainActor
    @Test("MarkdownTextView lays out code context views without drawing")
    func markdownTextViewLaysOutCodeContextViewsWithoutDrawing() throws {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 400)

        view.setContentImmediately(preprocessedContent(for: """
        ```swift
        let value = 1
        ```
        """))

        let codeView = try #require(view.contextViews.first as? CodeView)
        layout(view: view)

        #expect(codeView.superview === view)
        #expect(codeView.frame.width == view.bounds.width)
        #expect(codeView.frame.height > 0)
    }

    @MainActor
    @Test("MarkdownTextView routes table hits to nested table cell")
    func markdownTextViewRoutesTableHitsToNestedTableCell() throws {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 400)
        view.setContentImmediately(preprocessedContent(for: """
        Before

        | Name | Value |
        | --- | --- |
        | Alpha | Beta |

        After
        """))

        let tableView = try #require(view.contextViews.first as? TableView)
        layout(view: tableView)
        let overlayTarget = tableView.interactionTarget(at: CGPoint(x: 24, y: 24))
        let target = try #require(overlayTarget)

        #expect(target.isDescendant(of: tableView))
    }

    @MainActor
    @Test("MarkdownTextView routes code hits to nested code text")
    func markdownTextViewRoutesCodeHitsToNestedCodeText() throws {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 320, height: 400)
        view.setContentImmediately(preprocessedContent(for: """
        Before

        ```swift
        let value = 1
        ```

        After
        """))

        let codeView = try #require(view.contextViews.first as? CodeView)
        layout(view: codeView)
        let probe = view.convert(
            CGPoint(x: codeView.textView.bounds.midX, y: codeView.textView.bounds.midY),
            from: codeView.textView
        )
        let overlayTarget = codeView.interactionTarget(at: codeView.convert(probe, from: view))
        let target = try #require(overlayTarget)

        #expect(target === codeView.textView || target.isDescendant(of: codeView.textView))
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

private func testTableMetrics(maximumTextWidth: CGFloat) -> TableLayoutMetrics {
    TableLayoutMetrics(
        minimumColumnWidth: 20,
        maximumColumnWidth: maximumTextWidth + 20,
        horizontalCellPadding: 10,
        verticalCellPadding: 10,
        minimumRowHeight: 0
    )
}

@MainActor
private final class TextSelectionProbe: TextLabelViewDelegate {
    weak var changedLabel: TextLabelView?
    var changedSelection: NSRange?
    weak var draggedLabel: TextLabelView?
    var dragLocation: CGPoint?

    func textLabelView(_ textLabelView: TextLabelView, didChangeSelection selection: NSRange?) {
        changedLabel = textLabelView
        changedSelection = selection
    }

    func textLabelView(_ textLabelView: TextLabelView, didDragSelectionAt location: CGPoint) {
        draggedLabel = textLabelView
        dragLocation = location
    }
}

@MainActor
private func preprocessedContent(for markdown: String) -> MarkdownContent {
    MarkdownContent(
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
private func layout(view: MarkdownTextView) {
    #if canImport(UIKit)
        view.setNeedsLayout()
        view.layoutIfNeeded()
    #elseif canImport(AppKit)
        view.needsLayout = true
        view.layout()
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

@MainActor
private func extractTableCells(from scrollView: TestScrollView) -> [TextLabelView] {
    #if canImport(UIKit)
        scrollView.subviews.compactMap { $0 as? TextLabelView }
    #elseif canImport(AppKit)
        scrollView.documentView?.subviews.compactMap { $0 as? TextLabelView } ?? []
    #endif
}

@MainActor
private func paragraphAlignment(in cell: TextLabelView) -> NSTextAlignment? {
    guard cell.attributedText.length > 0 else { return nil }
    return (cell.attributedText.attribute(
        .paragraphStyle,
        at: 0,
        effectiveRange: nil
    ) as? NSParagraphStyle)?.alignment
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @MainActor
    private final class ScrollWheelProbe: NSView {
        private(set) var eventCount = 0

        override func scrollWheel(with _: NSEvent) {
            eventCount += 1
        }
    }

    @MainActor
    private func makeScrollWheelEvent(deltaY: Int32) throws -> NSEvent {
        let cgEvent = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: deltaY,
            wheel2: 0,
            wheel3: 0
        ))
        return try #require(NSEvent(cgEvent: cgEvent))
    }
#endif

private func language(at needle: String, in attributedString: NSAttributedString) -> String? {
    let range = (attributedString.string as NSString).range(of: needle)
    guard range.location != NSNotFound else { return nil }
    return attributedString.attribute(.coreTextLanguage, at: range.location, effectiveRange: nil) as? String
}
