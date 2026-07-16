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

        private lazy var scrollView: UIScrollView = .init()
        private lazy var gridView: GridView = .init()

        // MARK: - Properties

        private(set) var contents: [Rows] = []
        private(set) var columnAlignments: [RawTableColumnAlignment] = []

        private var cellManager = TableViewCellManager()
        private var widths: [CGFloat] = []
        private var heights: [CGFloat] = []
        private var theme: MarkdownTheme = .default
        weak var textSelectionDelegate: TextLabelViewDelegate?
        var linkHandler: ((LinkPayload, NSRange, CGPoint) -> Void)?

        // MARK: - Computed Properties

        private var numberOfRows: Int {
            contents.count
        }

        private var numberOfColumns: Int {
            contents.first?.count ?? 0
        }

        // MARK: - Initialization

        override init(frame: CGRect) {
            super.init(frame: frame)
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
        }

        func interactionTarget(at point: CGPoint, event: UIEvent? = nil) -> UIView? {
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

                    cell.frame = .init(
                        x: x + layoutMetrics.horizontalCellPadding + tableViewPadding,
                        y: y + layoutMetrics.verticalCellPadding + tableViewPadding,
                        width: max(0, columnWidth - layoutMetrics.horizontalCellPadding * 2),
                        height: ceil(idealCellSize.height)
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

        override var intrinsicContentSize: CGSize {
            .init(
                width: ceil(widths.reduce(0, +)) + tableViewPadding * 2,
                height: intrinsicContentHeight
            )
        }

        // MARK: - Cell Configuration

        private func configureCells() {
            cellManager.setTheme(theme)
            cellManager.setDelegate(self)
            cellManager.configureCells(
                for: contents,
                columnAlignments: columnAlignments,
                in: scrollView,
                metrics: layoutMetrics
            )

            widths = cellManager.widths
            heights = cellManager.heights

            gridView.padding = tableViewPadding
            gridView.update(widths: widths, heights: heights)

            gridView.setHeaderRow(numberOfRows > 0)
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
            sv.scrollerStyle = .overlay
            sv.drawsBackground = false
            return sv
        }()

        private lazy var gridView: GridView = .init()

        // MARK: - Properties

        private(set) var contents: [Rows] = []
        private(set) var columnAlignments: [RawTableColumnAlignment] = []

        private var cellManager = TableViewCellManager()
        private var widths: [CGFloat] = []
        private var heights: [CGFloat] = []
        private var theme: MarkdownTheme = .default
        weak var textSelectionDelegate: TextLabelViewDelegate?
        var linkHandler: ((LinkPayload, NSRange, CGPoint) -> Void)?

        // MARK: - Computed Properties

        private var numberOfRows: Int {
            contents.count
        }

        private var numberOfColumns: Int {
            contents.first?.count ?? 0
        }

        // MARK: - Initialization

        override init(frame: CGRect) {
            super.init(frame: frame)
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
        }

        func interactionTarget(at point: CGPoint) -> NSView? {
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
            if cell.isSelectable { return true }
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

                    cell.frame = .init(
                        x: x + layoutMetrics.horizontalCellPadding + tableViewPadding,
                        y: y + layoutMetrics.verticalCellPadding + tableViewPadding,
                        width: max(0, columnWidth - layoutMetrics.horizontalCellPadding * 2),
                        height: ceil(idealCellSize.height)
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

        override var intrinsicContentSize: CGSize {
            .init(
                width: ceil(widths.reduce(0, +)) + tableViewPadding * 2,
                height: intrinsicContentHeight
            )
        }

        // MARK: - Cell Configuration

        private func configureCells() {
            cellManager.setTheme(theme)
            cellManager.setDelegate(self)
            cellManager.configureCells(
                for: contents,
                columnAlignments: columnAlignments,
                in: gridView,
                metrics: layoutMetrics
            )

            widths = cellManager.widths
            heights = cellManager.heights

            gridView.padding = tableViewPadding
            gridView.update(widths: widths, heights: heights)

            gridView.setHeaderRow(numberOfRows > 0)
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
