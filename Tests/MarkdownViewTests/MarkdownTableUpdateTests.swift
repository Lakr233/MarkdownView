import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit

    private typealias ProbeScrollView = UIScrollView
#elseif canImport(AppKit)
    import AppKit

    private typealias ProbeScrollView = NSScrollView
#endif

/// A table re-renders every cell on every rebuild and only then asks whether
/// anything changed, so most of that work is thrown away while streaming. The
/// obvious fix is to ask first — which is only safe while a table still notices
/// every change it is supposed to notice.
///
/// These pin down what has to reach the cells.
struct MarkdownTableUpdateTests {
    @MainActor
    private func tableView(in view: MarkdownTextView) -> TableView? {
        view.contextViews.compactMap { $0 as? TableView }.first
    }

    @MainActor
    private func cells(in tableView: TableView) -> [TextLabelView] {
        guard let scrollView = tableView.subviews.first(where: { $0 is ProbeScrollView })
            as? ProbeScrollView
        else { return [] }
        #if canImport(UIKit)
            return scrollView.subviews
                .flatMap { [$0] + $0.subviews }
                .compactMap { $0 as? TextLabelView }
        #elseif canImport(AppKit)
            guard let documentView = scrollView.documentView else { return [] }
            return documentView.subviews.compactMap { $0 as? TextLabelView }
        #endif
    }

    @MainActor
    private func cellTexts(in view: MarkdownTextView) -> Set<String> {
        guard let tableView = tableView(in: view) else { return [] }
        return Set(cells(in: tableView).map(\.attributedText.string))
    }

    @MainActor
    private func table(_ rows: String, alignment: String = "| - | - |") -> String {
        """
        | A | B |
        \(alignment)
        \(rows)
        """
    }

    @MainActor
    @Test("A changed cell reaches the rendered table")
    func changedCellReachesTheTable() {
        let view = RenderProbe.view(table("| 原始内容 | keep |"))
        #expect(cellTexts(in: view).contains("原始内容"))

        RenderProbe.show(table("| 修改后的内容 | keep |"), in: view)

        let texts = cellTexts(in: view)
        #expect(texts.contains("修改后的内容"))
        #expect(!texts.contains("原始内容"))
    }

    @MainActor
    @Test("An added row reaches the rendered table")
    func addedRowReachesTheTable() {
        let view = RenderProbe.view(table("| 1 | one |"))
        let before = tableView(in: view)
        let beforeHeight = before?.intrinsicContentHeight ?? 0

        RenderProbe.show(table("""
        | 1 | one |
        | 2 | two |
        | 3 | three |
        """), in: view)

        let texts = cellTexts(in: view)
        #expect(texts.contains("two"))
        #expect(texts.contains("three"))
        #expect((tableView(in: view)?.intrinsicContentHeight ?? 0) > beforeHeight)
    }

    @MainActor
    @Test("A removed row leaves the rendered table")
    func removedRowLeavesTheTable() {
        let view = RenderProbe.view(table("""
        | 1 | one |
        | 2 | two |
        """))
        #expect(cellTexts(in: view).contains("two"))

        RenderProbe.show(table("| 1 | one |"), in: view)

        #expect(!cellTexts(in: view).contains("two"))
    }

    @MainActor
    @Test("A changed column alignment reaches the cells")
    func changedAlignmentReachesTheCells() {
        let view = RenderProbe.view(table("| 1 | 2 |", alignment: "| :-- | :-- |"))
        let leading = tableView(in: view).map { cells(in: $0) }?.compactMap {
            ($0.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                as? NSParagraphStyle)?.alignment
        } ?? []

        RenderProbe.show(table("| 1 | 2 |", alignment: "| --: | --: |"), in: view)
        let trailing = tableView(in: view).map { cells(in: $0) }?.compactMap {
            ($0.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                as? NSParagraphStyle)?.alignment
        } ?? []

        #expect(leading.contains(.left))
        #expect(trailing.contains(.right))
        #expect(!trailing.contains(.left))
    }

    @MainActor
    @Test("Rebuilding an unchanged table keeps the same cells")
    func unchangedTableKeepsItsCells() {
        let markdown = table("""
        | 1 | 中文单元格 |
        | 2 | another |
        """)
        let view = RenderProbe.view(markdown)
        RenderProbe.show(markdown, in: view)

        let first = tableView(in: view).map { cells(in: $0) } ?? []
        RenderProbe.show(markdown, in: view)
        let second = tableView(in: view).map { cells(in: $0) } ?? []

        #expect(!first.isEmpty)
        #expect(first.count == second.count)
        #expect(zip(first, second).allSatisfy { $0 === $1 })
    }

    @MainActor
    @Test("Table content still normalizes HTML line breaks")
    func htmlLineBreaksStayNormalized() {
        let view = RenderProbe.view(table("| 第一行<br>第二行 | plain |"))

        let texts = cellTexts(in: view)
        #expect(texts.contains("第一行\n第二行"))
        #expect(!texts.contains { $0.contains("<br>") })
    }

    @MainActor
    @Test("A table streamed row by row ends up complete")
    func streamedTableEndsUpComplete() {
        let final = table("""
        | 1 | one |
        | 2 | two |
        | 3 | three |
        """)
        let view = MarkdownTextView()

        let characters = Array(final)
        let step = max(1, characters.count / 12)
        var cursor = 0
        while cursor < characters.count {
            cursor = min(characters.count, cursor + step)
            RenderProbe.show(String(characters[0 ..< cursor]), in: view)
        }

        let texts = cellTexts(in: view)
        #expect(texts.contains("one"))
        #expect(texts.contains("two"))
        #expect(texts.contains("three"))
    }

    @MainActor
    @Test("A table replaced by a paragraph releases its view")
    func tableReplacedByTextReleasesItsView() {
        let view = RenderProbe.view(table("| 1 | 2 |"))
        #expect(tableView(in: view) != nil)

        RenderProbe.show("Just a paragraph now.", in: view)

        let strayVisible = view.subviews.compactMap { $0 as? TableView }.filter { !$0.isHidden }
        #expect(tableView(in: view) == nil)
        #expect(strayVisible.isEmpty)
    }

    @MainActor
    @Test("Inline styling inside a cell survives")
    func inlineStylingInsideCellsSurvives() {
        let view = RenderProbe.view(table("| **bold** | `code` |"))
        guard let tableView = tableView(in: view) else {
            Issue.record("no table view was built")
            return
        }

        let bodyFont = MarkdownTheme.default.fonts.body
        let fonts = cells(in: tableView).compactMap {
            $0.attributedText.length > 0
                ? $0.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont
                : nil
        }

        #expect(!fonts.isEmpty)
        #expect(fonts.contains { $0 != bodyFont })
    }
}
