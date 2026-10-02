import Foundation
@testable import MarkdownView
import Testing

/// The full table's sheet: every row measured once, columns stretched to
/// the viewport with the sheet's margins inside the outer ones, the header
/// pinned, and lookups that cost only the rows on screen.
@MainActor
struct TableSheetTests {
    private static let table = """
    | Name | Count |
    | :-- | --: |
    | beta | 10 |
    | alpha | 2 |
    | gamma | |
    """

    private func content(_ markdown: String = Self.table) throws -> TableSheetContent {
        let view = RenderProbe.view(markdown, width: 480)
        let table = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        return TableSheetContent(table)
    }

    // MARK: - Geometry

    @Test
    func `Columns narrower than the viewport stretch to fill it, margins included`() {
        let widths = TableSheetGeometry.columnWidths(natural: [100, 60], viewportWidth: 400, edgeInset: 10)
        #expect(widths.reduce(0, +) == 400)
        #expect(widths[0] - 10 == widths[1] - 10 + 40)
    }

    @Test
    func `Columns wider than the viewport keep their widths and add the margins`() {
        let widths = TableSheetGeometry.columnWidths(natural: [300, 300], viewportWidth: 400, edgeInset: 6)
        #expect(widths == [306, 306])
        let single = TableSheetGeometry.columnWidths(natural: [80], viewportWidth: 50, edgeInset: 6)
        #expect(single == [92])
    }

    @Test
    func `Cells sit edge to edge, row after row`() {
        let geometry = TableSheetGeometry(columnWidths: [100, 50], rowHeights: [40, 30, 20])
        #expect(geometry.contentSize == CGSize(width: 150, height: 90))
        #expect(geometry.frame(row: 2, column: 1) == CGRect(x: 100, y: 70, width: 50, height: 20))
        #expect(geometry.rowFrame(1) == CGRect(x: 0, y: 40, width: 150, height: 30))
    }

    @Test
    func `The header stays at the viewport's top, and moves down with an overscroll`() {
        let geometry = TableSheetGeometry(columnWidths: [100], rowHeights: [40, 30, 30])
        #expect(geometry.headerFrame(column: 0, viewportTop: 55).minY == 55)
        #expect(geometry.headerFrame(column: 0, viewportTop: -20).minY == 0)
    }

    @Test
    func `A rect finds exactly the rows and columns it touches, never the header`() {
        let geometry = TableSheetGeometry(columnWidths: [100, 100, 100], rowHeights: [40, 30, 30, 30, 30])
        #expect(geometry.bodyRows(in: CGRect(x: 0, y: 0, width: 10, height: 10)).isEmpty)
        #expect(geometry.bodyRows(in: CGRect(x: 0, y: 0, width: 10, height: 45)) == 1 ..< 2)
        #expect(geometry.bodyRows(in: CGRect(x: 0, y: 75, width: 10, height: 30)) == 2 ..< 4)
        #expect(geometry.bodyRows(in: CGRect(x: 0, y: 500, width: 10, height: 30)) == 4 ..< 5)
        #expect(geometry.columns(in: CGRect(x: 150, y: 0, width: 60, height: 10)) == 1 ..< 3)
        #expect(geometry.columns(in: CGRect(x: -50, y: 0, width: 20, height: 10)) == 0 ..< 1)
        #expect(TableSheetGeometry.empty.bodyRows(in: CGRect(x: 0, y: 0, width: 10, height: 10)).isEmpty)
    }

    // MARK: - Model

    @Test
    func `Every cell is styled and measured once, header first`() throws {
        let model = try TableSheetModel(content: content(), metrics: .compact)
        #expect(model.columnCount == 2)
        #expect(model.header.map(\.text.string) == ["Name", "Count"])
        #expect(model.body.count == 3)
        #expect(model.bodyHeights.count == 3)
        #expect(model.naturalWidths.allSatisfy { $0 >= TableLayoutMetrics.compact.minimumColumnWidth })
        #expect(model.naturalWidths.allSatisfy { $0 <= TableLayoutMetrics.compact.maximumColumnWidth })
        #expect(model.headerHeight >= TableLayoutMetrics.compact.minimumRowHeight)
        #expect(model.body.joined().allSatisfy { $0.textHeight > 0 || $0.text.length == 0 })
    }

    @Test
    func `Sorting orders the rows by value, empty cells last, and nil restores source order`() throws {
        let model = try TableSheetModel(content: content(), metrics: .compact)
        #expect(model.order(for: TableSort(column: 1, direction: .ascending)) == [1, 0, 2])
        #expect(model.order(for: TableSort(column: 1, direction: .descending)) == [0, 1, 2])
        #expect(model.order(for: TableSort(column: 0, direction: .ascending)) == [1, 0, 2])
        #expect(model.order(for: nil) == [0, 1, 2])
        let heights = model.rowHeights(in: [2, 0, 1])
        #expect(heights == [model.headerHeight, model.bodyHeights[2], model.bodyHeights[0], model.bodyHeights[1]])
    }
}
