import Litext
import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A very long table draws only its first rows, and opens in full in a sheet.
/// What it leaves out of the drawing must still be exactly what it was given:
/// the first rows in source order, a count that adds up, every row when
/// copied and in the sheet, and rows that move whole when the sheet sorts
/// them.
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

    // MARK: - Truncation

    @Test(arguments: [
        (0, 0, 0), (1, 0, 0), (2, 1, 0), (101, 100, 0), (102, 20, 81), (1001, 20, 980),
    ])
    func `The row limit keeps the first rows and counts the rest exactly`(rowCount: Int, visible: Int, hidden: Int) {
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
    @Test
    func `A table past the threshold draws its header and first twenty rows, and nothing more`() throws {
        let view = RenderProbe.view(Self.markdown(rows: 120))
        let table = try #require(tableView(in: view))

        #expect(drawnRows(of: table, columns: 2) == Self.expectedRows(1 ... 20))
        #expect(table.display.rowLimit.hiddenRowCount == 100)
        #expect(table.display.sourceRowIndices == Array(0 ..< 20))
        // No row stands in for the ones left out: the table is exactly as
        // tall as the twenty rows it draws.
        let twenty = try #require(tableView(in: RenderProbe.view(Self.markdown(rows: 20))))
        #expect(table.intrinsicContentHeight == twenty.intrinsicContentHeight)
    }

    @MainActor
    @Test
    func `A table of up to a hundred rows is drawn whole`() throws {
        let view = RenderProbe.view(Self.markdown(rows: 100))
        let table = try #require(tableView(in: view))

        #expect(drawnRows(of: table, columns: 2) == Self.expectedRows(1 ... 100))
        #expect(!table.display.rowLimit.isTruncated)
    }

    @MainActor
    @Test
    func `An inline table's only controls are its title bar's, and none sit over a cell`() throws {
        let view = RenderProbe.view(Self.markdown(rows: 120))
        let table = try #require(tableView(in: view))
        RenderProbe.layout(view)
        table.layoutSubtreeIfNeededOnBothPlatforms()

        var controls: [TableTapControl] = []
        var queue: [PlatformView] = [table]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if let control = view as? TableTapControl {
                controls.append(control)
            }
            queue.append(contentsOf: view.subviews)
        }
        #expect(Set(controls.map(ObjectIdentifier.init)) == Set([table.copyControl, table.expandControl].map(ObjectIdentifier.init)))
        #expect(table.sortControls.isEmpty)
        for control in controls {
            #expect(control.frame.maxY <= table.titleHeight + table.tableViewPadding + 0.5)
            for cell in table.cellViews {
                #expect(!control.frame.intersects(cell.convert(cell.bounds, to: table)))
            }
        }
    }

    @MainActor
    @Test
    func `A table growing past the threshold keeps its first rows and counts every new one`() throws {
        let view = MarkdownTextView()
        for rows in 98 ... 103 {
            RenderProbe.show(Self.markdown(rows: rows), in: view)
            let table = try #require(tableView(in: view))
            let drawn = rows > 100 ? 20 : rows
            #expect(drawnRows(of: table, columns: 2) == Self.expectedRows(1 ... drawn))
            #expect(table.display.rowLimit.hiddenRowCount == rows - drawn)
        }
    }

    @MainActor
    @Test
    func `Copying the document still yields every row, drawn or not`() throws {
        let markdown = "Before.\n\n" + Self.markdown(rows: 120) + "\nAfter."
        let view = RenderProbe.view(markdown)
        view.textLabelView.selectAll()
        let copied = try #require(view.textLabelView.selectedPlainText())

        let expected = Self.expectedRows(1 ... 120).map { $0.joined(separator: "\t") }.joined(separator: "\n")
        #expect(copied.contains(expected))

        let table = try #require(tableView(in: view))
        let representation = table.attributedStringRepresentation().string
        for row in Self.expectedRows(1 ... 120) {
            #expect(representation.contains(row.joined(separator: "\t")))
        }
    }

    @MainActor
    @Test
    func `Drawn cells stay selectable`() throws {
        let view = RenderProbe.view(Self.markdown(rows: 120))
        let table = try #require(tableView(in: view))
        let selectable = table.cellViews.allSatisfy(\.isSelectable)
        #expect(selectable)
    }

    // MARK: - Header cells

    @MainActor
    @Test
    func `An inline header cell reserves no accessory space`() throws {
        let markdown = """
        | Short | A considerably long header title |
        | - | - |
        | 1 | x |
        """
        let view = RenderProbe.view(markdown)
        let table = try #require(tableView(in: view))
        RenderProbe.layout(view)
        table.layoutSubtreeIfNeededOnBothPlatforms()

        let header = try #require(table.cellViews[safe: 1])
        let body = try #require(table.cellViews[safe: 3])
        #expect(abs(header.frame.minX - body.frame.minX) < 0.5)
        #expect(ceil(header.intrinsicContentSize.width) <= header.frame.width + 0.5)
    }

    @MainActor
    @Test
    func `A resize moves cells to their column's alignment without resizing them`() throws {
        let markdown = """
        | Left | Centre | Right |
        | :--- | :----: | ----: |
        | a | b | c |
        | longer left | longer centre | longer right |
        """
        let view = RenderProbe.view(markdown, width: 480)
        let table = try #require(tableView(in: view))
        table.layoutSubtreeIfNeededOnBothPlatforms()
        let narrow = table.cellViews.map(\.frame)

        RenderProbe.show(markdown, in: view, width: 900)
        table.layoutSubtreeIfNeededOnBothPlatforms()
        let wide = table.cellViews.map(\.frame)

        // The columns stretched, so the cells moved, but none was resized.
        #expect(narrow.map(\.size) == wide.map(\.size))
        #expect(narrow != wide)
        for frames in [narrow, wide] {
            // The two body rows hold text of different widths in each column.
            let (short, long) = (Array(frames[3 ..< 6]), Array(frames[6 ..< 9]))
            #expect(abs(short[0].minX - long[0].minX) < 0.5)
            #expect(abs(short[1].midX - long[1].midX) < 0.5)
            #expect(abs(short[2].maxX - long[2].maxX) < 0.5)
        }
    }

    @MainActor
    @Test
    func `A header slot keeps text and glyph apart inside the cell padding`() {
        let column = CGRect(x: 10, y: 2, width: 120, height: 38)
        let slot = TableHeaderSlot(columnFrame: column, horizontalPadding: 9, accessoryWidth: TableHeaderAccessory.width)
        #expect(slot.textFrame.minX == 19)
        #expect(slot.textFrame.maxX == 130 - 9 - TableHeaderAccessory.width)
        #expect(abs(slot.glyphFrame.maxX - (column.maxX - 9)) < 0.001)
        #expect(slot.glyphFrame.minX >= slot.textFrame.maxX + TableHeaderAccessory.spacing)
        #expect(slot.glyphFrame.midY == column.midY)
    }

    // MARK: - Opening the full table

    @MainActor
    @Test
    func `The sheet shows every row and cell exactly, links, code and alignment included`() throws {
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
    @Test
    func `Numbers sort by value, grouping, signs and units included`() {
        let cells = ["10", "9", "1,000", "-3", "2.5", "$4", "50%", "−7"]
        let ascending = order(cells, .ascending).map { cells[$0] }
        #expect(ascending == ["−7", "-3", "2.5", "$4", "9", "10", "50%", "1,000"])
        let descending = order(cells, .descending).map { cells[$0] }
        #expect(descending == ascending.reversed())
    }

    @MainActor
    @Test
    func `Text sorts the way Finder sorts names, after numbers`() {
        let cells = ["item 10", "item 2", "Banana", "apple", "3", "NaN"]
        let ascending = order(cells, .ascending).map { cells[$0] }
        #expect(ascending == ["3", "apple", "Banana", "item 2", "item 10", "NaN"])
    }

    @MainActor
    @Test
    func `Empty cells stay last in either direction`() {
        let cells = ["", "2", " ", "1", "b", "a"]
        let ascending = order(cells, .ascending)
        let descending = order(cells, .descending)
        #expect(ascending.map { cells[$0] } == ["1", "2", "a", "b", "", " "])
        #expect(descending.map { cells[$0] } == ["b", "a", "2", "1", "", " "])
    }

    @MainActor
    @Test
    func `Equal cells keep their source order in either direction`() {
        let rows = [["1", "first"], ["2", "x"], ["1", "second"], ["2", "y"], ["1", "third"]]
        let ascending = TableSort(column: 0, direction: .ascending).order(of: rows)
        let descending = TableSort(column: 0, direction: .descending).order(of: rows)
        #expect(ascending == [0, 2, 4, 1, 3])
        #expect(descending == [1, 3, 0, 2, 4])
    }

    @Test
    func `Tapping a header cycles ascending, descending, source order`() {
        let first = TableSort.next(afterTapping: 1, current: nil)
        #expect(first == TableSort(column: 1, direction: .ascending))
        let second = TableSort.next(afterTapping: 1, current: first)
        #expect(second == TableSort(column: 1, direction: .descending))
        #expect(TableSort.next(afterTapping: 1, current: second) == nil)
        #expect(TableSort.next(afterTapping: 0, current: second) == TableSort(column: 0, direction: .ascending))
    }

    @MainActor
    @Test
    func `Sorting the sheet moves rows whole and can be undone`() throws {
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
    @Test
    func `The sorted column shows a chevron for its direction; the others none`() throws {
        let view = RenderProbe.view(Self.markdown(rows: 3, columns: 3))
        let sheet = try TableSheetContent(#require(tableView(in: view))).makeTableView()
        #expect(sheet.sortControls.count == 3)
        #expect(sheet.sortControls.allSatisfy { $0.symbolImage == nil })

        sheet.sortControls[2].performTap()
        #expect(sheet.sortControls[2].symbolImage != nil)
        #expect(sheet.sortControls[0].symbolImage == nil)
        #expect(sheet.sortControls[1].symbolImage == nil)
    }

    // MARK: - Only changed cells are restyled

    @MainActor
    @Test
    func `A streamed token restyles only the cell it changed`() throws {
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
    @Test
    func `A new row restyles only its own cells, and none past the threshold`() throws {
        let view = MarkdownTextView()
        RenderProbe.show(Self.markdown(rows: 3, columns: 3), in: view)
        let table = try #require(tableView(in: view))

        RenderProbe.show(Self.markdown(rows: 4, columns: 3), in: view)
        #expect(table.lastRestyledCellCount == 3)

        RenderProbe.show(Self.markdown(rows: 110, columns: 3), in: view)
        RenderProbe.show(Self.markdown(rows: 111, columns: 3), in: view)
        #expect(table.lastRestyledCellCount == 0, "a row past the threshold is counted, not drawn")
        #expect(table.display.rowLimit.hiddenRowCount == 91)
    }

    @MainActor
    @Test
    func `A theme change restyles every cell`() throws {
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
    @Test
    func `Diffed cells match a table built from scratch`() throws {
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
