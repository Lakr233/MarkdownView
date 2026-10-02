@testable import MarkdownView
import MarkdownParser
import Testing
import UIKit

/// The UIKit half of a table's fixed frame: a title bar with its buttons
/// above columns that scroll inside the border, without an indicator.
@MainActor
struct TableFrameUIKitTests {
    private func makeTable(width: CGFloat) throws -> TableView {
        let view = MarkdownTextView()
        view.setContentImmediately(.init(
            parserResult: MarkdownParser().parse("""
            | Column one | Column two | Column three | Column four | Column five |
            | - | - | - | - | - |
            | a considerably long cell | b considerably long cell | c | d | e |
            """),
            theme: .default
        ))
        view.frame = .init(x: 0, y: 0, width: width, height: view.boundingSize(for: width).height)
        view.layoutIfNeeded()
        let table = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        table.layoutIfNeeded()
        return table
    }

    @Test("The title bar sits above the scrolling columns")
    func titleBarAboveColumns() throws {
        let table = try makeTable(width: 320)
        let scrollView = try #require(table.subviews.first { $0 is UIScrollView } as? UIScrollView)
        #expect(table.titleHeight > 0)
        #expect(abs(scrollView.frame.minY - (table.tableViewPadding + table.titleHeight)) < 0.001)
        #expect(!scrollView.showsHorizontalScrollIndicator)
        for control in [table.copyControl, table.expandControl] {
            #expect(control.superview === table)
            #expect(control.frame.maxY <= scrollView.frame.minY + 0.5)
        }
    }

    @Test("Scrolling moves the column lines and leaves the frame in place")
    func scrollingMovesColumnLines() throws {
        let table = try makeTable(width: 320)
        let scrollView = try #require(table.subviews.first { $0 is UIScrollView } as? UIScrollView)
        let grid = try #require(table.subviews.first { $0 is GridView } as? GridView)
        #expect(scrollView.contentSize.width > scrollView.bounds.width)
        let before = grid.columnLinePositions
        scrollView.contentOffset.x = 30
        #expect(zip(before, grid.columnLinePositions).allSatisfy { abs($0 - $1 - 30) < 0.001 })
        #expect(grid.frame == table.bounds)
    }
}
