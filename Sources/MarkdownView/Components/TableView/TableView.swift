//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext
import MarkdownParser

private func fittedTableColumnWidths(
    _ naturalWidths: [CGFloat],
    to availableWidth: CGFloat,
    outerPadding: CGFloat
) -> [CGFloat] {
    guard !naturalWidths.isEmpty, availableWidth.isFinite, availableWidth > 0 else {
        return naturalWidths
    }

    let naturalWidth = naturalWidths.reduce(0, +)
    let minimumColumnsWidth = max(0, availableWidth - outerPadding * 2)
    let extraWidth = minimumColumnsWidth - naturalWidth
    guard extraWidth > 0 else { return naturalWidths }

    let extraWidthPerColumn = extraWidth / CGFloat(naturalWidths.count)
    var fittedWidths = naturalWidths.map { $0 + extraWidthPerColumn }
    if let lastIndex = fittedWidths.indices.last {
        fittedWidths[lastIndex] += minimumColumnsWidth - fittedWidths.reduce(0, +)
    }
    return fittedWidths
}

#if canImport(UIKit)
    import UIKit

    final class TableView: UIView {
        typealias Rows = [NSAttributedString]

        // MARK: - Constants

        private let tableViewPadding: CGFloat = 2
        private let layoutMetrics = TableLayoutMetrics.compact

        // MARK: - UI Components

        private lazy var scrollView: HorizontalClippingScrollView = .init()
        private lazy var gridView: GridView = .init()

        // MARK: - Properties

        /// Every row, header first, as given: what copying the table yields
        /// and what the full-table sheet shows.
        private(set) var contents: [Rows] = []
        private(set) var columnAlignments: [RawTableColumnAlignment] = []
        let mode: TableViewMode
        /// The rows drawn, picked from `contents`.
        private(set) var display = TableDisplay(contents: [], mode: .inline, sort: nil)
        /// The column the sheet is sorted by; always nil inline.
        private(set) var sort: TableSort?

        private var cellManager = TableViewCellManager()
        private var widths: [CGFloat] = []
        private var heights: [CGFloat] = []
        private(set) var theme: MarkdownTheme = .default
        weak var textSelectionDelegate: TextLabelViewDelegate?
        var linkHandler: ((LinkPayload, NSRange, CGPoint) -> Void)?
        /// Opens the full table. Unset, the table presents it in a sheet.
        var expandHandler: ((TableView) -> Void)?
        /// Told after a sort changed what the table draws.
        var sortHandler: ((TableView) -> Void)?

        /// The header's trailing button that opens the full table.
        private(set) lazy var expandControl: TableTapControl = makeExpandControl()
        /// The last row of a truncated table, counting the rows left out.
        private(set) lazy var summaryControl: TableTapControl = makeSummaryControl()
        /// One per column in the sheet, over the header cell.
        private(set) var sortControls: [TableTapControl] = []
        /// What the summary row's text was built from, so a stream that
        /// does not change the count does not rebuild it.
        private var summarySource: (hiddenRowCount: Int, theme: MarkdownTheme, size: CGSize)?

        // MARK: - Computed Properties

        private var numberOfRows: Int {
            display.rows.count
        }

        /// Cells the last content change styled and measured again.
        var lastRestyledCellCount: Int {
            cellManager.lastRestyledCellCount
        }

        /// The cells drawn, row by row.
        var cellViews: [TextLabelView] {
            cellManager.cells
        }

        private var numberOfColumns: Int {
            contents.first?.count ?? 0
        }

        // MARK: - Initialization

        override init(frame: CGRect) {
            mode = .inline
            super.init(frame: frame)
            configureSubviews()
        }

        init(mode: TableViewMode) {
            self.mode = mode
            super.init(frame: .zero)
            configureSubviews()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func configureSubviews() {
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.backgroundColor = .clear
            addSubview(scrollView)
            scrollView.addSubview(gridView)
        }

        func setContents(
            _ contents: [Rows],
            columnAlignments: [RawTableColumnAlignment] = []
        ) {
            // replace <br> in each items with newline characters
            var builder = contents
            for x in 0 ..< contents.count {
                for y in 0 ..< contents[x].count {
                    let content = contents[x][y]
                    let processedContent = processContent(
                        input: content,
                        replacing: "<br>",
                        with: "\n"
                    )
                    builder[x][y] = processedContent
                }
            }
            guard !contentsEqual(self.contents, builder)
                || self.columnAlignments != columnAlignments
            else { return }
            self.contents = builder
            self.columnAlignments = columnAlignments
            configureCells()
            setNeedsLayout()
        }

        func setTheme(_ theme: MarkdownTheme) {
            guard self.theme != theme else { return }
            self.theme = theme
            updateThemeAppearance()
            guard !contents.isEmpty else { return }
            configureCells()
            setNeedsLayout()
        }

        private func updateThemeAppearance() {
            gridView.setTheme(theme)
            cellManager.setTheme(theme)
        }

        // MARK: - Layout

        override func layoutSubviews() {
            super.layoutSubviews()

            scrollView.frame = bounds
            let layoutWidths = fittedTableColumnWidths(
                widths,
                to: bounds.width,
                outerPadding: tableViewPadding
            )
            let contentSize = CGSize(
                width: layoutWidths.reduce(0, +) + tableViewPadding * 2,
                height: intrinsicContentHeight
            )
            scrollView.contentSize = contentSize
            gridView.frame = CGRect(origin: .zero, size: contentSize)
            gridView.update(widths: layoutWidths, heights: heights)

            layoutCells(using: layoutWidths)
            layoutControls(using: layoutWidths)
        }

        func interactionTarget(at point: CGPoint, event: UIEvent? = nil) -> UIView? {
            if let control = control(at: point) {
                return control
            }
            for cell in cellManager.cells.reversed() {
                let cellPoint = cell.convert(point, from: self)
                guard cell.bounds.contains(cellPoint) else { continue }
                if let target = cell.hitTest(cellPoint, with: event) {
                    return target
                }
            }

            let scrollPoint = scrollView.convert(point, from: self)
            if scrollView.bounds.contains(scrollPoint),
               scrollView.contentSize.width > scrollView.bounds.width + 1
            {
                return scrollView
            }

            return nil
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard isUserInteractionEnabled,
                  !isHidden,
                  alpha > 0.01,
                  bounds.contains(point)
            else { return nil }

            return interactionTarget(at: point, event: event)
        }

        private func layoutCells(using layoutWidths: [CGFloat]) {
            guard !cellManager.cellSizes.isEmpty, !cellManager.cells.isEmpty else {
                return
            }
            guard layoutWidths.count == numberOfColumns else {
                assertionFailure("Table layout width count must match its column count.")
                return
            }

            var x: CGFloat = 0
            var y: CGFloat = 0

            for row in 0 ..< numberOfRows {
                for column in 0 ..< numberOfColumns {
                    let index = row * numberOfColumns + column
                    let cell = cellManager.cells[index]
                    let idealCellSize = cell.intrinsicContentSize
                    let columnWidth = layoutWidths[column]
                    let cellHeight = ceil(idealCellSize.height)
                    let verticalOffset = max(0, (heights[row] - cellHeight) / 2)

                    let accessoryWidth = row == 0
                        ? display.headerAccessoryWidths[safe: column] ?? 0
                        : 0

                    cell.frame = .init(
                        x: x + layoutMetrics.horizontalCellPadding + tableViewPadding,
                        y: y + verticalOffset + tableViewPadding,
                        width: max(0, columnWidth - layoutMetrics.horizontalCellPadding * 2 - accessoryWidth),
                        height: cellHeight
                    )

                    x += columnWidth
                }
                x = 0
                y += heights[row]
            }
        }

        // MARK: - Content Size

        var intrinsicContentHeight: CGFloat {
            ceil(heights.reduce(0, +)) + tableViewPadding * 2
        }

        /// The width the columns need before any is stretched to fill the viewport.
        var naturalContentWidth: CGFloat {
            widths.reduce(0, +) + tableViewPadding * 2
        }

        override var intrinsicContentSize: CGSize {
            .init(
                width: Self.noIntrinsicMetric,
                height: intrinsicContentHeight
            )
        }

        // MARK: - Cell Configuration

        private func configureCells() {
            display = TableDisplay(contents: contents, mode: mode, sort: sort)
            cellManager.setTheme(theme)
            cellManager.setDelegate(self)
            cellManager.configureCells(
                for: display.rows,
                columnAlignments: columnAlignments,
                headerAccessoryWidths: display.headerAccessoryWidths,
                in: scrollView,
                metrics: layoutMetrics
            )

            widths = cellManager.widths
            heights = cellManager.heights
            if display.rowLimit.isTruncated {
                let size = summaryTextSize(hiddenRowCount: display.rowLimit.hiddenRowCount)
                widths = TableDisplay.columnWidths(
                    widths,
                    fitting: size.width + layoutMetrics.horizontalCellPadding * 2
                )
                heights.append(max(
                    layoutMetrics.minimumRowHeight,
                    size.height + layoutMetrics.verticalCellPadding * 2
                ))
            }

            gridView.padding = tableViewPadding
            gridView.update(widths: widths, heights: heights)

            gridView.setHeaderRow(numberOfRows > 0)
            gridView.setMergesLastRow(display.rowLimit.isTruncated)
            configureControls(in: scrollView)
        }

        /// Sorts the sheet by `sort`, or puts it back in source order for nil.
        func applySort(_ sort: TableSort?) {
            guard mode == .sheet, self.sort != sort else { return }
            self.sort = sort
            guard !contents.isEmpty else { return }
            configureCells()
            setNeedsLayout()
            sortHandler?(self)
        }

        private func processContent(
            input: NSAttributedString,
            replacing occurs: String,
            with replaced: String
        ) -> NSAttributedString {
            guard input.string.contains(occurs) else { return input }
            let mutableAttributedString = input.mutableCopy() as! NSMutableAttributedString
            let mutableString = mutableAttributedString.mutableString
            mutableString.replaceOccurrences(
                of: occurs,
                with: replaced,
                options: [],
                range: NSRange(location: 0, length: mutableString.length)
            )
            return mutableAttributedString
        }

        /// What produced the cells this view is currently showing.
        ///
        /// Rendering a table means turning every cell's inline nodes into an
        /// attributed string, and a stream asks for that on every token even
        /// when the table itself has not changed since the last one. Comparing
        /// the source the cells came from lets the builder skip that work
        /// instead of doing it and then discovering it was not needed.
        private struct RenderedSource {
            let rows: [RawTableRow]
            let columnAlignments: [RawTableColumnAlignment]
            let theme: MarkdownTheme
            let localeIdentifier: String
            let carriesMath: Bool
            let representedText: NSAttributedString
        }

        private var renderedSource: RenderedSource?

        /// The text standing in for this table, if it already shows `rows`.
        ///
        /// Cells also depend on the content's locale, which picks their
        /// fallback fonts, and on its rendered math, which the rows only name.
        /// Math images are not compared, so a table whose cells hold math is
        /// rendered again; a table without math never reads them.
        func representedText(
            reusingRows rows: [RawTableRow],
            columnAlignments: [RawTableColumnAlignment],
            theme: MarkdownTheme,
            content: MarkdownContent
        ) -> NSAttributedString? {
            guard let renderedSource,
                  !renderedSource.carriesMath,
                  renderedSource.theme == theme,
                  renderedSource.localeIdentifier == content.locale.identifier,
                  renderedSource.columnAlignments == columnAlignments,
                  renderedSource.rows == rows
            else { return nil }
            return renderedSource.representedText
        }

        func rememberRenderedSource(
            rows: [RawTableRow],
            columnAlignments: [RawTableColumnAlignment],
            theme: MarkdownTheme,
            content: MarkdownContent,
            representedText: NSAttributedString
        ) {
            renderedSource = .init(
                rows: rows,
                columnAlignments: columnAlignments,
                theme: theme,
                localeIdentifier: content.locale.identifier,
                carriesMath: rows.contains { $0.carriesMath },
                representedText: representedText
            )
        }

        /// Drops the reuse record, so the next build renders the cells again
        /// even though the rows and the theme are the ones it already drew.
        /// What the cells rendered *to* can change without either of them
        /// moving — an inline decoration reading state this table cannot see.
        func forgetRenderedSource() {
            renderedSource = nil
        }

        private func contentsEqual(_ lhs: [Rows], _ rhs: [Rows]) -> Bool {
            guard lhs.count == rhs.count else { return false }
            for rowIndex in lhs.indices {
                guard lhs[rowIndex].count == rhs[rowIndex].count else { return false }
                for columnIndex in lhs[rowIndex].indices {
                    guard lhs[rowIndex][columnIndex].isEqual(to: rhs[rowIndex][columnIndex]) else {
                        return false
                    }
                }
            }
            return true
        }
    }

    // MARK: - TextLabelViewDelegate

    extension TableView: TextLabelViewDelegate {
        func textLabelView(_ label: TextLabelView, didChangeSelection selection: NSRange?) {
            textSelectionDelegate?.textLabelView(label, didChangeSelection: selection)
        }

        func textLabelView(_ label: TextLabelView, didDragSelectionAt location: CGPoint) {
            textSelectionDelegate?.textLabelView(label, didDragSelectionAt: location)
        }

        func textLabelView(_ label: TextLabelView, didTapHighlightRegion highlightRegion: TextLabel.HighlightRegion, at location: CGPoint) {
            let link = highlightRegion.attributes[NSAttributedString.Key.link]
            let range = highlightRegion.stringRange

            // Convert location from cell to MarkdownTextView coordinate system
            let locationInMarkdownView = superview.flatMap { label.convert(location, to: $0) } ?? location

            if let url = link as? URL {
                linkHandler?(.url(url), range, locationInMarkdownView)
            } else if let string = link as? String {
                linkHandler?(.string(string), range, locationInMarkdownView)
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    final class TableView: NSView {
        typealias Rows = [NSAttributedString]

        // MARK: - Constants

        private let tableViewPadding: CGFloat = 2
        private let layoutMetrics = TableLayoutMetrics.regular

        // MARK: - UI Components

        private lazy var scrollView: HorizontalScrollView = {
            let sv = HorizontalScrollView()
            sv.hasVerticalScroller = false
            sv.hasHorizontalScroller = true
            sv.autohidesScrollers = true
            sv.drawsBackground = false
            return sv
        }()

        private lazy var gridView: GridView = .init()

        // MARK: - Properties

        /// Every row, header first, as given: what copying the table yields
        /// and what the full-table sheet shows.
        private(set) var contents: [Rows] = []
        private(set) var columnAlignments: [RawTableColumnAlignment] = []
        let mode: TableViewMode
        /// The rows drawn, picked from `contents`.
        private(set) var display = TableDisplay(contents: [], mode: .inline, sort: nil)
        /// The column the sheet is sorted by; always nil inline.
        private(set) var sort: TableSort?

        private var cellManager = TableViewCellManager()
        private var widths: [CGFloat] = []
        private var heights: [CGFloat] = []
        private(set) var theme: MarkdownTheme = .default
        weak var textSelectionDelegate: TextLabelViewDelegate?
        var linkHandler: ((LinkPayload, NSRange, CGPoint) -> Void)?
        /// Opens the full table. Unset, the table presents it in a sheet.
        var expandHandler: ((TableView) -> Void)?
        /// Told after a sort changed what the table draws.
        var sortHandler: ((TableView) -> Void)?

        /// The header's trailing button that opens the full table.
        private(set) lazy var expandControl: TableTapControl = makeExpandControl()
        /// The last row of a truncated table, counting the rows left out.
        private(set) lazy var summaryControl: TableTapControl = makeSummaryControl()
        /// One per column in the sheet, over the header cell.
        private(set) var sortControls: [TableTapControl] = []
        /// What the summary row's text was built from, so a stream that
        /// does not change the count does not rebuild it.
        private var summarySource: (hiddenRowCount: Int, theme: MarkdownTheme, size: CGSize)?

        // MARK: - Computed Properties

        private var numberOfRows: Int {
            display.rows.count
        }

        /// Cells the last content change styled and measured again.
        var lastRestyledCellCount: Int {
            cellManager.lastRestyledCellCount
        }

        /// The cells drawn, row by row.
        var cellViews: [TextLabelView] {
            cellManager.cells
        }

        private var numberOfColumns: Int {
            contents.first?.count ?? 0
        }

        // MARK: - Initialization

        override init(frame: CGRect) {
            mode = .inline
            super.init(frame: frame)
            configureSubviews()
        }

        init(mode: TableViewMode) {
            self.mode = mode
            super.init(frame: .zero)
            configureSubviews()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isFlipped: Bool {
            true
        }

        // MARK: - Setup

        private func configureSubviews() {
            addSubview(scrollView)
            scrollView.documentView = gridView
        }

        func setContents(
            _ contents: [Rows],
            columnAlignments: [RawTableColumnAlignment] = []
        ) {
            var builder = contents
            for x in 0 ..< contents.count {
                for y in 0 ..< contents[x].count {
                    let content = contents[x][y]
                    let processedContent = processContent(
                        input: content,
                        replacing: "<br>",
                        with: "\n"
                    )
                    builder[x][y] = processedContent
                }
            }
            guard !contentsEqual(self.contents, builder)
                || self.columnAlignments != columnAlignments
            else { return }
            self.contents = builder
            self.columnAlignments = columnAlignments
            configureCells()
            needsLayout = true
        }

        func setTheme(_ theme: MarkdownTheme) {
            guard self.theme != theme else { return }
            self.theme = theme
            updateThemeAppearance()
            guard !contents.isEmpty else { return }
            configureCells()
            needsLayout = true
        }

        private func updateThemeAppearance() {
            gridView.setTheme(theme)
            cellManager.setTheme(theme)
        }

        // MARK: - Layout

        override func layout() {
            super.layout()

            scrollView.frame = bounds
            let layoutWidths = fittedTableColumnWidths(
                widths,
                to: bounds.width,
                outerPadding: tableViewPadding
            )
            let contentSize = CGSize(
                width: layoutWidths.reduce(0, +) + tableViewPadding * 2,
                height: intrinsicContentHeight
            )
            gridView.frame = CGRect(origin: .zero, size: contentSize)
            gridView.update(widths: layoutWidths, heights: heights)
            layoutCells(using: layoutWidths)
            layoutControls(using: layoutWidths)
        }

        func interactionTarget(at point: CGPoint) -> NSView? {
            if let control = control(at: point) {
                return control
            }
            for cell in cellManager.cells.reversed() {
                let cellPoint = cell.convert(point, from: self)
                guard cell.bounds.contains(cellPoint) else { continue }
                // Unlike UIKit, AppKit's TextLabelView.hitTest falls back to
                // super and reports a hit even for inert text, so only route
                // to cells that can actually handle interaction.
                guard cellSupportsInteraction(cell) else { continue }
                if let target = cell.hitTest(cellPoint) {
                    return target
                }
                return cell
            }

            let scrollPoint = scrollView.convert(point, from: self)
            if scrollView.bounds.contains(scrollPoint),
               let documentView = scrollView.documentView,
               documentView.bounds.width > scrollView.bounds.width + 1
            {
                return scrollView
            }

            return nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let localPoint = superview.map { convert(point, from: $0) } ?? point
            guard !isHidden, bounds.contains(localPoint) else { return nil }
            return interactionTarget(at: localPoint)
        }

        private func cellSupportsInteraction(_ cell: TextLabelView) -> Bool {
            if cell.isSelectable {
                return true
            }
            let text = cell.attributedText
            var containsLink = false
            text.enumerateAttribute(
                .link,
                in: NSRange(location: 0, length: text.length)
            ) { value, _, stop in
                guard value != nil else { return }
                containsLink = true
                stop.pointee = true
            }
            return containsLink
        }

        private func layoutCells(using layoutWidths: [CGFloat]) {
            guard !cellManager.cellSizes.isEmpty, !cellManager.cells.isEmpty else {
                return
            }
            guard layoutWidths.count == numberOfColumns else {
                assertionFailure("Table layout width count must match its column count.")
                return
            }

            var x: CGFloat = 0
            var y: CGFloat = 0

            for row in 0 ..< numberOfRows {
                for column in 0 ..< numberOfColumns {
                    let index = row * numberOfColumns + column
                    let cell = cellManager.cells[index]
                    let idealCellSize = cell.intrinsicContentSize
                    let columnWidth = layoutWidths[column]
                    let cellHeight = ceil(idealCellSize.height)
                    let verticalOffset = max(0, (heights[row] - cellHeight) / 2)

                    let accessoryWidth = row == 0
                        ? display.headerAccessoryWidths[safe: column] ?? 0
                        : 0

                    cell.frame = .init(
                        x: x + layoutMetrics.horizontalCellPadding + tableViewPadding,
                        y: y + verticalOffset + tableViewPadding,
                        width: max(0, columnWidth - layoutMetrics.horizontalCellPadding * 2 - accessoryWidth),
                        height: cellHeight
                    )

                    x += columnWidth
                }
                x = 0
                y += heights[row]
            }
        }

        // MARK: - Content Size

        var intrinsicContentHeight: CGFloat {
            ceil(heights.reduce(0, +)) + tableViewPadding * 2
        }

        /// The width the columns need before any is stretched to fill the viewport.
        var naturalContentWidth: CGFloat {
            widths.reduce(0, +) + tableViewPadding * 2
        }

        override var intrinsicContentSize: CGSize {
            .init(
                width: Self.noIntrinsicMetric,
                height: intrinsicContentHeight
            )
        }

        // MARK: - Cell Configuration

        private func configureCells() {
            display = TableDisplay(contents: contents, mode: mode, sort: sort)
            cellManager.setTheme(theme)
            cellManager.setDelegate(self)
            cellManager.configureCells(
                for: display.rows,
                columnAlignments: columnAlignments,
                headerAccessoryWidths: display.headerAccessoryWidths,
                in: gridView,
                metrics: layoutMetrics
            )

            widths = cellManager.widths
            heights = cellManager.heights
            if display.rowLimit.isTruncated {
                let size = summaryTextSize(hiddenRowCount: display.rowLimit.hiddenRowCount)
                widths = TableDisplay.columnWidths(
                    widths,
                    fitting: size.width + layoutMetrics.horizontalCellPadding * 2
                )
                heights.append(max(
                    layoutMetrics.minimumRowHeight,
                    size.height + layoutMetrics.verticalCellPadding * 2
                ))
            }

            gridView.padding = tableViewPadding
            gridView.update(widths: widths, heights: heights)

            gridView.setHeaderRow(numberOfRows > 0)
            gridView.setMergesLastRow(display.rowLimit.isTruncated)
            configureControls(in: gridView)
        }

        /// Sorts the sheet by `sort`, or puts it back in source order for nil.
        func applySort(_ sort: TableSort?) {
            guard mode == .sheet, self.sort != sort else { return }
            self.sort = sort
            guard !contents.isEmpty else { return }
            configureCells()
            needsLayout = true
            sortHandler?(self)
        }

        private func processContent(
            input: NSAttributedString,
            replacing occurs: String,
            with replaced: String
        ) -> NSAttributedString {
            guard input.string.contains(occurs) else { return input }
            let mutableAttributedString = input.mutableCopy() as! NSMutableAttributedString
            let mutableString = mutableAttributedString.mutableString
            mutableString.replaceOccurrences(
                of: occurs,
                with: replaced,
                options: [],
                range: NSRange(location: 0, length: mutableString.length)
            )
            return mutableAttributedString
        }

        /// What produced the cells this view is currently showing.
        ///
        /// Rendering a table means turning every cell's inline nodes into an
        /// attributed string, and a stream asks for that on every token even
        /// when the table itself has not changed since the last one. Comparing
        /// the source the cells came from lets the builder skip that work
        /// instead of doing it and then discovering it was not needed.
        private struct RenderedSource {
            let rows: [RawTableRow]
            let columnAlignments: [RawTableColumnAlignment]
            let theme: MarkdownTheme
            let localeIdentifier: String
            let carriesMath: Bool
            let representedText: NSAttributedString
        }

        private var renderedSource: RenderedSource?

        /// The text standing in for this table, if it already shows `rows`.
        ///
        /// Cells also depend on the content's locale, which picks their
        /// fallback fonts, and on its rendered math, which the rows only name.
        /// Math images are not compared, so a table whose cells hold math is
        /// rendered again; a table without math never reads them.
        func representedText(
            reusingRows rows: [RawTableRow],
            columnAlignments: [RawTableColumnAlignment],
            theme: MarkdownTheme,
            content: MarkdownContent
        ) -> NSAttributedString? {
            guard let renderedSource,
                  !renderedSource.carriesMath,
                  renderedSource.theme == theme,
                  renderedSource.localeIdentifier == content.locale.identifier,
                  renderedSource.columnAlignments == columnAlignments,
                  renderedSource.rows == rows
            else { return nil }
            return renderedSource.representedText
        }

        func rememberRenderedSource(
            rows: [RawTableRow],
            columnAlignments: [RawTableColumnAlignment],
            theme: MarkdownTheme,
            content: MarkdownContent,
            representedText: NSAttributedString
        ) {
            renderedSource = .init(
                rows: rows,
                columnAlignments: columnAlignments,
                theme: theme,
                localeIdentifier: content.locale.identifier,
                carriesMath: rows.contains { $0.carriesMath },
                representedText: representedText
            )
        }

        /// Drops the reuse record, so the next build renders the cells again
        /// even though the rows and the theme are the ones it already drew.
        /// What the cells rendered *to* can change without either of them
        /// moving — an inline decoration reading state this table cannot see.
        func forgetRenderedSource() {
            renderedSource = nil
        }

        private func contentsEqual(_ lhs: [Rows], _ rhs: [Rows]) -> Bool {
            guard lhs.count == rhs.count else { return false }
            for rowIndex in lhs.indices {
                guard lhs[rowIndex].count == rhs[rowIndex].count else { return false }
                for columnIndex in lhs[rowIndex].indices {
                    guard lhs[rowIndex][columnIndex].isEqual(to: rhs[rowIndex][columnIndex]) else {
                        return false
                    }
                }
            }
            return true
        }
    }

    // MARK: - TextLabelViewDelegate

    extension TableView: TextLabelViewDelegate {
        func textLabelView(_ label: TextLabelView, didChangeSelection selection: NSRange?) {
            textSelectionDelegate?.textLabelView(label, didChangeSelection: selection)
        }

        func textLabelView(_ label: TextLabelView, didDragSelectionAt location: CGPoint) {
            textSelectionDelegate?.textLabelView(label, didDragSelectionAt: location)
        }

        func textLabelView(_ label: TextLabelView, didTapHighlightRegion highlightRegion: TextLabel.HighlightRegion, at location: CGPoint) {
            let link = highlightRegion.attributes[NSAttributedString.Key.link]
            let range = highlightRegion.stringRange

            let locationInMarkdownView = superview.flatMap { label.convert(location, to: $0) } ?? location

            if let url = link as? URL {
                linkHandler?(.url(url), range, locationInMarkdownView)
            } else if let string = link as? String {
                linkHandler?(.string(string), range, locationInMarkdownView)
            }
        }
    }
#endif

private extension RawTableRow {
    /// Whether any cell draws math, whose image the rows only name.
    var carriesMath: Bool {
        cells.contains { cell in
            !cell.content.collect { node -> [Void] in
                if case .math = node {
                    return [()]
                }
                return []
            }.isEmpty
        }
    }
}

// MARK: - Controls

#if canImport(UIKit) || canImport(AppKit)
    extension TableView {
        /// The control under `point`, in the table's coordinates.
        fileprivate func control(at point: CGPoint) -> TableTapControl? {
            let controls = [expandControl, summaryControl] + sortControls
            return controls.first { control in
                guard !control.isHidden, control.superview != nil else { return false }
                return control.bounds.contains(control.convert(point, from: self))
            }
        }

        fileprivate func makeExpandControl() -> TableTapControl {
            let control = TableTapControl()
            control.setSymbol(TableSymbol.expand, fallback: TableSymbol.expandFallback)
            control.setAccessibleTitle(TableSummaryText.showFullTable)
            control.isHidden = true
            control.handler = { [weak self] in self?.openFullTable() }
            return control
        }

        fileprivate func makeSummaryControl() -> TableTapControl {
            let control = TableTapControl()
            control.isHidden = true
            control.handler = { [weak self] in self?.openFullTable() }
            return control
        }

        /// The theme the cells were last styled with.
        var currentTheme: MarkdownTheme {
            theme
        }

        /// Opens every row, through `expandHandler` when one is set.
        func openFullTable() {
            if let expandHandler {
                expandHandler(self)
            } else {
                TableSheetPresenter.present(self)
            }
        }

        /// The summary text's size, built again only when the count or the
        /// theme moved.
        fileprivate func summaryTextSize(hiddenRowCount: Int) -> CGSize {
            if let summarySource,
               summarySource.hiddenRowCount == hiddenRowCount,
               summarySource.theme == theme
            {
                return summarySource.size
            }
            let text = TableSummaryText.attributedText(hiddenRowCount: hiddenRowCount, theme: theme)
            let bounds = text.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let size = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
            summaryControl.attributedText = text
            summaryControl.setAccessibleTitle(text.string)
            summarySource = (hiddenRowCount, theme, size)
            return size
        }

        /// Adds the controls this mode draws, sized to the current columns.
        fileprivate func configureControls(in container: PlatformView) {
            switch mode {
            case .inline:
                for control in [expandControl, summaryControl] where control.superview !== container {
                    container.addSubview(control)
                }
                expandControl.isHidden = numberOfColumns == 0
                summaryControl.isHidden = !display.rowLimit.isTruncated
            case .sheet:
                while sortControls.count < numberOfColumns {
                    let column = sortControls.count
                    let control = TableTapControl()
                    control.handler = { [weak self] in
                        guard let self else { return }
                        applySort(TableSort.next(afterTapping: column, current: sort))
                    }
                    container.addSubview(control)
                    sortControls.append(control)
                }
                while sortControls.count > numberOfColumns {
                    sortControls.removeLast().removeFromSuperview()
                }
                for (column, control) in sortControls.enumerated() {
                    let direction = sort?.column == column ? sort?.direction : nil
                    switch direction {
                    case .ascending:
                        control.setSymbol(TableSymbol.sortAscending)
                    case .descending:
                        control.setSymbol(TableSymbol.sortDescending)
                    case nil:
                        control.setSymbol(nil)
                    }
                    control.setAccessibleTitle(display.rows.first?[safe: column]?.string)
                }
            }
        }

        /// Places the controls over the columns as laid out at `layoutWidths`.
        fileprivate func layoutControls(using layoutWidths: [CGFloat]) {
            guard let headerHeight = heights.first, layoutWidths.count == numberOfColumns else {
                expandControl.isHidden = true
                summaryControl.isHidden = true
                return
            }
            var x = tableViewPadding
            let headerFrames = layoutWidths.map { width -> CGRect in
                defer { x += width }
                return CGRect(x: x, y: tableViewPadding, width: width, height: headerHeight)
            }

            switch mode {
            case .inline:
                if let lastColumn = headerFrames.last {
                    let slot = TableHeaderSlot(
                        columnFrame: lastColumn,
                        horizontalPadding: layoutMetrics.horizontalCellPadding,
                        accessoryWidth: TableHeaderAccessory.width
                    )
                    expandControl.frame = slot.hitFrame
                    expandControl.glyphFrame = slot.glyphFrame.offsetBy(
                        dx: -slot.hitFrame.minX,
                        dy: -slot.hitFrame.minY
                    )
                }
                if display.rowLimit.isTruncated, let summaryHeight = heights.last {
                    let frame = CGRect(
                        x: tableViewPadding,
                        y: tableViewPadding + heights.dropLast().reduce(0, +),
                        width: layoutWidths.reduce(0, +),
                        height: summaryHeight
                    )
                    summaryControl.frame = frame
                    summaryControl.textFrame = CGRect(
                        x: layoutMetrics.horizontalCellPadding,
                        y: 0,
                        width: max(0, frame.width - layoutMetrics.horizontalCellPadding * 2),
                        height: frame.height
                    )
                }
            case .sheet:
                for (column, control) in sortControls.enumerated() {
                    guard let columnFrame = headerFrames[safe: column] else { continue }
                    let slot = TableHeaderSlot(
                        columnFrame: columnFrame,
                        horizontalPadding: layoutMetrics.horizontalCellPadding,
                        accessoryWidth: TableHeaderAccessory.width
                    )
                    control.frame = columnFrame
                    control.glyphFrame = slot.glyphFrame.offsetBy(
                        dx: -columnFrame.minX,
                        dy: -columnFrame.minY
                    )
                }
            }
        }
    }
#endif
