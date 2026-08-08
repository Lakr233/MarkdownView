@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct ListMarkerLayoutTests {
    private let font = PlatformFont.systemFont(ofSize: 17)
    private let lineOrigin = CGPoint(x: 24, y: 100)

    @Test("The marker column and its gap fill exactly one level of indent")
    func columnFillsOneIndentLevel() {
        #expect(ListMarkerLayout.size + ListMarkerLayout.spacing == ListMarkerLayout.indent)

        let column = ListMarkerLayout.column(lineOrigin: lineOrigin, font: font)
        // The column ends before the text, and never reaches into the level above it.
        #expect(column.maxX == lineOrigin.x - ListMarkerLayout.spacing)
        #expect(column.minX == lineOrigin.x - ListMarkerLayout.indent)
    }

    @Test("Markers of different kinds share one center")
    func markerKindsShareOneCenter() {
        // A bullet, a circled number and a checkbox are drawn by three separate
        // callbacks; all three place themselves through this column, so a list that
        // mixes them lines its markers up instead of stepping left and right.
        let column = ListMarkerLayout.column(lineOrigin: lineOrigin, font: font)

        let symbols: [CGSize] = [
            .init(width: 16, height: 16), // square
            .init(width: 15.5, height: 14.5), // a symbol taller than it is wide
            .init(width: 11, height: 13),
        ]
        for symbol in symbols {
            let rect = ListMarkerLayout.fit(imageSize: symbol, in: column)
            #expect(abs(rect.midX - column.midX) < 0.001)
            #expect(abs(rect.midY - column.midY) < 0.001)
            // Fitting keeps the symbol's shape and holds it inside the column.
            #expect(rect.width <= column.width + 0.001)
            #expect(rect.height <= column.height + 0.001)
            #expect(abs(rect.width / rect.height - symbol.width / symbol.height) < 0.001)
            // One side fills the column, so symbols of unequal boxes still read alike.
            #expect(abs(max(rect.width, rect.height) - ListMarkerLayout.size) < 0.001)
        }
    }

    @Test("A marker sits on the cap height of the text, not on the line's bounds")
    func markerSitsOnCapHeight() {
        let column = ListMarkerLayout.column(lineOrigin: lineOrigin, font: font)
        #expect(abs(column.midY - (lineOrigin.y + font.capHeight / 2)) < 0.001)

        // A line growing taller — inline code, math, an image — moves the line's
        // typographic bounds but must leave the marker where its neighbors are.
        let taller = ListMarkerLayout.column(
            lineOrigin: lineOrigin,
            font: PlatformFont.systemFont(ofSize: 17)
        )
        #expect(taller.midY == column.midY)
    }

    @Test("A larger marker font carries the column up with the text")
    func columnFollowsTheFont() {
        let large = ListMarkerLayout.column(
            lineOrigin: lineOrigin,
            font: PlatformFont.systemFont(ofSize: 34)
        )
        let small = ListMarkerLayout.column(lineOrigin: lineOrigin, font: font)
        #expect(large.midY > small.midY)
        #expect(large.midX == small.midX)
    }

    @Test("A symbol with an empty box falls back to the column")
    func emptySymbolFallsBackToColumn() {
        let column = ListMarkerLayout.column(lineOrigin: lineOrigin, font: font)
        let rect = ListMarkerLayout.fit(imageSize: .zero, in: column)
        #expect(rect == column)
    }
}
