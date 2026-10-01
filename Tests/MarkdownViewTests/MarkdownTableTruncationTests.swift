import Litext
import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A long table draws its first rows and a row counting the rest, and opens
/// in full in a sheet. What it leaves out of the drawing must still be exactly
/// what it was given: the first rows in source order, a count that adds up,
/// every row when copied and in the sheet, and rows that move whole when the
/// sheet sorts them.
struct MarkdownTableTruncationTests {
    // MARK: - Helpers

    private static func markdown(rows: Int, columns: Int = 2, alignment: String? = nil) -> String {
        var out = "| " + (1 ... columns).map { "H\($0)" }.joined(separator: " | ") + " |\n"
        out += alignment ?? ("|" + String(repeating: " - |", count: columns))
        out += "\n"
        for row in 0 ..< rows {
            out += "| " + (1 ... columns).map { "r\(row + 1)c\($0)" }.joined(separator: " | ") + " |\n"
        }
        return out
    }

    @MainActor
    private func tableView(in view: MarkdownTextView) -> TableView? {
        view.contextViews.compactMap { $0 as? TableView }.first
    }

    /// The text a cell shows, without the spacers that pad inline code.
    @MainActor
    private func text(of cell: TextLabelView) -> String {
        cell.attributedText.string.replacingOccurrences(of: TextLabel.Attachment.replacementText, with: "")
    }

    @MainActor
    private func drawnRows(of tableView: TableView, columns: Int) -> [[String]] {
        let texts = tableView.cellViews.map { text(of: $0) }
        return stride(from: 0, to: texts.count, by: columns).map { Array(texts[$0 ..< min(texts.count, $0 + columns)]) }
    }

    private static func expectedRows(_ rows: ClosedRange<Int>, columns: Int = 2) -> [[String]] {
        [(1 ... columns).map { "H\($0)" }] + rows.map { row in (1 ... columns).map { "r\(row)c\($0)" } }
    }

    private static func integers(in text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    // MARK: - Truncation

    @Test("The row limit keeps the first rows and counts the rest exactly", arguments: [
        (0, 0, 0), (1, 0, 0), (2, 1, 0), (9, 8, 0), (10, 8, 1), (13, 8, 4), (1001, 8, 992),
    ])
    func rowLimitCounts(rowCount: Int, visible: Int, hidden: Int) {
        let limit = TableRowLimit(rowCount: rowCount)
        #expect(limit.visibleRowCount == visible)
        #expect(limit.hiddenRowCount == hidden)
        #expect(limit.isTruncated == (hidden > 0))
        let rows = Array(0 ..< rowCount)
        #expect(limit.visibleRows(of: rows) == Array(rows.prefix(rowCount == 0 ? 0 : 1 + visible)))
        if rowCount > 0 {
            #expect(visible + hidden == rowCount - 1, "every content row is either drawn or counted")
        }
    }

    @MainActor
    @Test("A long table draws its header and first eight rows in source order")
    func longTableDrawsFirstRows() throws {
        let view = RenderProbe.view(Self.markdown(rows: 12))
        let table = try #require(tableView(in: view))

        #expect(drawnRows(of: table, columns: 2) == Self.expectedRows(1 ... 8))
        #expect(table.display.rowLimit.hiddenRowCount == 4)
        #expect(table.display.sourceRowIndices == Array(0 ..< 8))
        #expect(!table.summaryControl.isHidden)
        #expect(Self.integers(in: table.summaryControl.attributedText?.string ?? "") == [4])
    }

    @MainActor
    @Test("A table of eight rows or fewer is drawn whole, without a summary row")
    func shortTableIsWhole() throws {
        let view = RenderProbe.view(Self.markdown(rows: 8))
        let table = try #require(tableView(in: view))

        #expect(drawnRows(of: table, columns: 2) == Self.expectedRows(1 ... 8))
        #expect(!table.display.rowLimit.isTruncated)
        #expect(table.summaryControl.isHidden)
        #expect(!table.expandControl.isHidden)
    }

    @MainActor
    @Test("The summary row's count is exact and only View All is underlined", arguments: [1, 2, 7, 120])
    func summaryText(hidden: Int) {
        let text = TableSummaryText.attributedText(hiddenRowCount: hidden, theme: .default)
        #expect(Self.integers(in: text.string) == [hidden])
        #expect(text.string.hasSuffix(TableSummaryText.viewAll))

        let viewAll = (text.string as NSString).range(of: TableSummaryText.viewAll, options: .backwards)
        var underlined: [NSRange] = []
        text.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let value = value as? Int, value != 0 {
                underlined.append(range)
            }
        }
        #expect(underlined == [viewAll])
        let paragraph = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(paragraph?.alignment == .natural, "the summary row is leading aligned")
    }

    @MainActor
    @Test("A table growing past the cap keeps its first rows and counts every new one")
    func streamedTableCrossesTheCap() throws {
        let view = MarkdownTextView()
        for rows in 6 ... 15 {
            RenderProbe.show(Self.markdown(rows: rows), in: view)
            let table = try #require(tableView(in: view))
            #expect(drawnRows(of: table, columns: 2) == Self.expectedRows(1 ... min(8, rows)))
            #expect(table.display.rowLimit.hiddenRowCount == max(0, rows - 8))
            #expect(table.summaryControl.isHidden == (rows <= 8))
            if rows > 8 {
                #expect(Self.integers(in: table.summaryControl.attributedText?.string ?? "") == [rows - 8])
            }
        }
    }

    @MainActor
    @Test("Copying the document still yields every row, drawn or not")
    func copyYieldsEveryRow() throws {
        let markdown = "Before.\n\n" + Self.markdown(rows: 12) + "\nAfter."
        let view = RenderProbe.view(markdown)
        view.textLabelView.selectAll()
        let copied = try #require(view.textLabelView.selectedPlainText())

        let expected = Self.expectedRows(1 ... 12).map { $0.joined(separator: "\t") }.joined(separator: "\n")
        #expect(copied.contains(expected))

        let table = try #require(tableView(in: view))
        let representation = table.attributedStringRepresentation().string
        for row in Self.expectedRows(1 ... 12) {
            #expect(representation.contains(row.joined(separator: "\t")))
        }
    }

    @MainActor
    @Test("Drawn cells stay selectable")
    func drawnCellsStaySelectable() throws {
        let view = RenderProbe.view(Self.markdown(rows: 12))
        let table = try #require(tableView(in: view))
        let selectable = table.cellViews.allSatisfy { $0.isSelectable }
        #expect(selectable)
    }

    // MARK: - Header accessory width

    @MainActor
    @Test("The expand button's width is counted into the last column", arguments: [480, 200])
    func expandButtonNeverCoversHeaderText(width: CGFloat) throws {
        let markdown = """
        | Short | A considerably long header title |
        | - | - |
        | 1 | x |
        """
        let view = RenderProbe.view(markdown, width: width)
        let table = try #require(tableView(in: view))
        RenderProbe.layout(view)
        table.layoutSubtreeIfNeededOnBothPlatforms()

        let header = try #require(table.cellViews[safe: 1])
        let control = table.expandControl
        #expect(!control.isHidden)
        let headerFrame = header.frame
        let glyphFrame = control.glyphFrame.offsetBy(dx: control.frame.minX, dy: control.frame.minY)

        #expect(headerFrame.maxX <= control.frame.minX + 0.5, "the header text slot reaches into the button")
        #expect(!headerFrame.intersects(glyphFrame))
        #expect(
            ceil(header.intrinsicContentSize.width) <= headerFrame.width + 0.5,
            "the header text needs \(header.intrinsicContentSize.width) but has \(headerFrame.width)"
        )
        // One line: the header wraps no more than a body cell does.
        let body = try #require(table.cellViews[safe: 3])
        #expect(abs(header.intrinsicContentSize.height - body.intrinsicContentSize.height) < 1)
    }

    @MainActor
    @Test("A header slot keeps text and glyph apart inside the cell padding")
    func headerSlotGeometry() {
        let column = CGRect(x: 10, y: 2, width: 120, height: 38)
        let slot = TableHeaderSlot(columnFrame: column, horizontalPadding: 9, accessoryWidth: TableHeaderAccessory.width)
        #expect(slot.textFrame.minX == 19)
        #expect(slot.textFrame.maxX == 130 - 9 - TableHeaderAccessory.width)
        #expect(abs(slot.glyphFrame.maxX - (column.maxX - 9)) < 0.001)
        #expect(slot.glyphFrame.minX >= slot.textFrame.maxX + TableHeaderAccessory.spacing)
        #expect(slot.hitFrame.minX == slot.textFrame.maxX)
        #expect(slot.hitFrame.maxX == column.maxX)
        #expect(slot.glyphFrame.midY == column.midY)
    }

    @Test("The summary row widens only the last column, and only as far as it needs")
    func summaryWidensLastColumn() {
        #expect(TableDisplay.columnWidths([88, 88], fitting: 300) == [88, 212])
        #expect(TableDisplay.columnWidths([200, 200], fitting: 300) == [200, 200])
        #expect(TableDisplay.columnWidths([88, 88], fitting: nil) == [88, 88])
        #expect(TableDisplay.columnWidths([], fitting: 300) == [])
    }

    // MARK: - Opening the full table

    @MainActor
    @Test("The expand button and the summary row both open the full table")
    func controlsOpenTheFullTable() throws {
        let view = RenderProbe.view(Self.markdown(rows: 12))
        let table = try #require(tableView(in: view))
        var opened: [TableView] = []
        table.expandHandler = { opened.append($0) }

        table.expandControl.performTap()
        table.summaryControl.performTap()

        #expect(opened.count == 2)
        #expect(opened.allSatisfy { $0 === table })
    }

    @MainActor
    @Test("Taps reach the expand button over its glyph and the header cell over its text")
    func hitTestingSeparatesButtonAndText() throws {
        let view = RenderProbe.view(Self.markdown(rows: 12))
        let table = try #require(tableView(in: view))
        RenderProbe.layout(view)
        table.layoutSubtreeIfNeededOnBothPlatforms()

        let control = table.expandControl
        let glyph = control.glyphFrame.offsetBy(dx: control.frame.minX, dy: control.frame.minY)
        let glyphCenter = CGPoint(x: glyph.midX, y: glyph.midY)
        #expect(table.interactionTarget(at: glyphCenter) === control)

        let header = try #require(table.cellViews[safe: 1])
        let headerCenter = CGPoint(x: header.frame.minX + 2, y: header.frame.midY)
        #expect(table.interactionTarget(at: headerCenter) !== control)

        let summary = table.summaryControl
        let summaryPoint = CGPoint(x: summary.frame.midX, y: summary.frame.midY)
        #expect(table.interactionTarget(at: summaryPoint) === summary)
    }

    @MainActor
    @Test("The sheet shows every row and cell exactly, links, code and alignment included")
    func sheetShowsEveryRow() throws {
        var markdown = """
        | Name | Link | Code | Amount |
        | :-- | :-: | -- | --: |

        """
        for row in 1 ... 14 {
            markdown += "| n\(row) | [site \(row)](https://example.com/\(row)) | `c\(row)` | \(row * 7) |\n"
        }
        let view = RenderProbe.view(markdown)
        let inline = try #require(tableView(in: view))
        let sheet = TableSheetContent(inline).makeTableView()

        #expect(sheet.contents.count == 15)
        #expect(sheet.cellViews.count == 15 * 4)
        #expect(!sheet.display.rowLimit.isTruncated)
        for (row, rowContent) in inline.contents.enumerated() {
            for (column, source) in rowContent.enumerated() {
                let cell = sheet.cellViews[row * 4 + column]
                #expect(cell.attributedText.string == source.string)
            }
        }

        let link = sheet.cellViews[2 * 4 + 1].attributedText
        let linkLocation = (link.string as NSString).range(of: "site 2").location
        let linkValue = link.attribute(.link, at: linkLocation, effectiveRange: nil)
        #expect((linkValue as? URL)?.absoluteString == "https://example.com/2" || (linkValue as? String) == "https://example.com/2")

        let code = sheet.cellViews[3 * 4 + 2].attributedText
        let codeLocation = (code.string as NSString).range(of: "c3").location
        #expect(code.attribute(.inlineCodeBackground, at: codeLocation, effectiveRange: nil) != nil)

        let alignments = (0 ..< 4).map { column in
            (sheet.cellViews[4 + column].attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                as? NSParagraphStyle)?.alignment
        }
        #expect(alignments == [.left, .center, .left, .right])
    }

    // MARK: - Sorting

    @MainActor
    private func order(_ cells: [String], _ direction: TableSort.Direction) -> [Int] {
        TableSort(column: 0, direction: direction).order(of: cells.map { [$0] })
    }

    @MainActor
    @Test("Numbers sort by value, grouping, signs and units included")
    func numbersSortByValue() {
        let cells = ["10", "9", "1,000", "-3", "2.5", "$4", "50%", "−7"]
        let ascending = order(cells, .ascending).map { cells[$0] }
        #expect(ascending == ["−7", "-3", "2.5", "$4", "9", "10", "50%", "1,000"])
        let descending = order(cells, .descending).map { cells[$0] }
        #expect(descending == ascending.reversed())
    }

    @MainActor
    @Test("Text sorts the way Finder sorts names, after numbers")
    func textSortsNaturally() {
        let cells = ["item 10", "item 2", "Banana", "apple", "3", "NaN"]
        let ascending = order(cells, .ascending).map { cells[$0] }
        #expect(ascending == ["3", "apple", "Banana", "item 2", "item 10", "NaN"])
    }

    @MainActor
    @Test("Empty cells stay last in either direction")
    func emptyCellsStayLast() {
        let cells = ["", "2", " ", "1", "b", "a"]
        let ascending = order(cells, .ascending)
        let descending = order(cells, .descending)
        #expect(ascending.map { cells[$0] } == ["1", "2", "a", "b", "", " "])
        #expect(descending.map { cells[$0] } == ["b", "a", "2", "1", "", " "])
    }

    @MainActor
    @Test("Equal cells keep their source order in either direction")
    func sortIsStable() {
        let rows = [["1", "first"], ["2", "x"], ["1", "second"], ["2", "y"], ["1", "third"]]
        let ascending = TableSort(column: 0, direction: .ascending).order(of: rows)
        let descending = TableSort(column: 0, direction: .descending).order(of: rows)
        #expect(ascending == [0, 2, 4, 1, 3])
        #expect(descending == [1, 3, 0, 2, 4])
    }

    @Test("Tapping a header cycles ascending, descending, source order")
    func tapCycle() {
        let first = TableSort.next(afterTapping: 1, current: nil)
        #expect(first == TableSort(column: 1, direction: .ascending))
        let second = TableSort.next(afterTapping: 1, current: first)
        #expect(second == TableSort(column: 1, direction: .descending))
        #expect(TableSort.next(afterTapping: 1, current: second) == nil)
        #expect(TableSort.next(afterTapping: 0, current: second) == TableSort(column: 0, direction: .ascending))
    }

    @MainActor
    @Test("Sorting the sheet moves rows whole and can be undone")
    func sheetSortMovesRowsWhole() throws {
        var markdown = "| Name | Score | Note |\n| - | - | - |\n"
        let scores = [30, 4, 100, 4, 57, 12, 99, 4, 0, 21, 8, 75]
        for (index, score) in scores.enumerated() {
            markdown += "| name\(index) | \(score) | note\(index) |\n"
        }
        let view = RenderProbe.view(markdown)
        let inline = try #require(tableView(in: view))
        let sheet = TableSheetContent(inline).makeTableView()
        let source = drawnRows(of: sheet, columns: 3)
        var sortChanges = 0
        sheet.sortHandler = { _ in sortChanges += 1 }

        sheet.sortControls[1].performTap()
        #expect(sheet.sort == TableSort(column: 1, direction: .ascending))
        let ascending = drawnRows(of: sheet, columns: 3)
        #expect(ascending.first == source.first, "the header stays put")
        #expect(Set(ascending.dropFirst().map { $0.joined(separator: "|") }) == Set(source.dropFirst().map { $0.joined(separator: "|") }))
        #expect(ascending.dropFirst().map { Int($0[1])! } == scores.sorted())
        for row in ascending.dropFirst() {
            let index = try #require(Int(row[0].dropFirst(4)))
            #expect(row == ["name\(index)", "\(scores[index])", "note\(index)"], "a row was split by the sort")
        }
        // Equal scores keep their source order.
        #expect(ascending.dropFirst().filter { $0[1] == "4" }.map(\.[0]) == ["name1", "name3", "name7"])
        for (drawn, sourceIndex) in zip(sheet.display.rows.dropFirst(), sheet.display.sourceRowIndices) {
            let same = drawn.elementsEqual(sheet.contents[sourceIndex + 1], by: ===)
            #expect(same)
        }

        sheet.sortControls[1].performTap()
        let descending = drawnRows(of: sheet, columns: 3)
        #expect(descending.dropFirst().map { Int($0[1])! } == scores.sorted(by: >))
        #expect(descending.dropFirst().filter { $0[1] == "4" }.map(\.[0]) == ["name1", "name3", "name7"])

        sheet.sortControls[1].performTap()
        #expect(sheet.sort == nil)
        #expect(drawnRows(of: sheet, columns: 3) == source)
        #expect(sortChanges == 3)
        let unchanged = sheet.contents.elementsEqual(inline.contents) { $0.elementsEqual($1, by: ===) }
        #expect(unchanged, "sorting changed the rows held")
    }

    @MainActor
    @Test("The sorted column shows a chevron for its direction; the others none")
    func sortIndicators() throws {
        let view = RenderProbe.view(Self.markdown(rows: 3, columns: 3))
        let sheet = TableSheetContent(try #require(tableView(in: view))).makeTableView()
        #expect(sheet.sortControls.count == 3)
        #expect(sheet.sortControls.allSatisfy { $0.symbolImage == nil })

        sheet.sortControls[2].performTap()
        #expect(sheet.sortControls[2].symbolImage != nil)
        #expect(sheet.sortControls[0].symbolImage == nil)
        #expect(sheet.sortControls[1].symbolImage == nil)
    }

    // MARK: - Only changed cells are restyled

    @MainActor
    @Test("A streamed token restyles only the cell it changed")
    func onlyChangedCellsRestyle() throws {
        let view = MarkdownTextView()
        let base = Self.markdown(rows: 5, columns: 4)
        RenderProbe.show(base + "| a | b | c | d", in: view)
        let table = try #require(tableView(in: view))
        let before = table.cellViews
        let beforeTexts = before.map { text(of: $0) }

        RenderProbe.show(base + "| a | b | c | de", in: view)
        #expect(table.lastRestyledCellCount == 1)
        let after = table.cellViews
        #expect(after.count == before.count)
        #expect(zip(before, after).allSatisfy { $0 === $1 })
        let afterTexts = after.map { text(of: $0) }
        #expect(afterTexts.last == "de")
        #expect(Array(afterTexts.dropLast()) == Array(beforeTexts.dropLast()))
    }

    @MainActor
    @Test("A new row restyles only its own cells, and none past the cap")
    func newRowRestylesItsCells() throws {
        let view = MarkdownTextView()
        RenderProbe.show(Self.markdown(rows: 3, columns: 3), in: view)
        let table = try #require(tableView(in: view))

        RenderProbe.show(Self.markdown(rows: 4, columns: 3), in: view)
        #expect(table.lastRestyledCellCount == 3)

        RenderProbe.show(Self.markdown(rows: 10, columns: 3), in: view)
        RenderProbe.show(Self.markdown(rows: 11, columns: 3), in: view)
        #expect(table.lastRestyledCellCount == 0, "a row past the cap is counted, not drawn")
        #expect(Self.integers(in: table.summaryControl.attributedText?.string ?? "") == [3])
    }

    @MainActor
    @Test("A theme change restyles every cell")
    func themeChangeRestylesEveryCell() throws {
        let markdown = Self.markdown(rows: 3, columns: 2)
        let view = RenderProbe.view(markdown)
        let table = try #require(tableView(in: view))
        var theme = MarkdownTheme.default
        theme.colors.body = .systemRed
        view.theme = theme
        RenderProbe.show(markdown, in: view, theme: theme)

        #expect(table.lastRestyledCellCount == 8)
        let color = table.cellViews[2].attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor
        #expect(color == .systemRed)
    }

    @MainActor
    @Test("Diffed cells match a table built from scratch")
    func diffedCellsMatchAFreshBuild() throws {
        let final = Self.markdown(rows: 11, columns: 3, alignment: "| :-- | :-: | --: |")
        let streamed = MarkdownTextView()
        let characters = Array(final)
        for end in stride(from: 1, through: characters.count, by: 3) {
            RenderProbe.show(String(characters[0 ..< end]), in: streamed)
        }
        RenderProbe.show(final, in: streamed)
        let fresh = RenderProbe.view(final)

        let lhs = try #require(tableView(in: streamed))
        let rhs = try #require(tableView(in: fresh))
        #expect(lhs.cellViews.count == rhs.cellViews.count)
        for (left, right) in zip(lhs.cellViews, rhs.cellViews) {
            #expect(RenderProbe.digest(left.attributedText) == RenderProbe.digest(right.attributedText))
            #expect(left.frame == right.frame)
        }
        #expect(lhs.intrinsicContentHeight == rhs.intrinsicContentHeight)
    }
}

private extension TableView {
    func layoutSubtreeIfNeededOnBothPlatforms() {
        #if canImport(UIKit)
            setNeedsLayout()
            layoutIfNeeded()
        #elseif canImport(AppKit)
            needsLayout = true
            layoutSubtreeIfNeeded()
        #endif
    }
}
