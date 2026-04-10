//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext

#if canImport(UIKit)
    import UIKit

    final class TableView: UIView {
        typealias Rows = [NSAttributedString]

        // MARK: - Constants

        private let tableViewPadding: CGFloat = 2
        private let cellPadding: CGFloat = 10
        private let maximumCellWidth: CGFloat = 200

        // MARK: - UI Components

        private lazy var scrollView: UIScrollView = .init()
        private lazy var gridView: GridView = .init()

        // MARK: - Properties

        private(set) var contents: [Rows] = [] {
            didSet {
                configureCells()
                setNeedsLayout()
            }
        }

        private var cellManager = TableViewCellManager()
        private var widths: [CGFloat] = []
        private var heights: [CGFloat] = []
        private var theme: MarkdownTheme = .default
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

        func setContents(_ contents: [Rows]) {
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
            guard !contentsEqual(self.contents, builder) else { return }
            self.contents = builder
        }

        func setTheme(_ theme: MarkdownTheme) {
            self.theme = theme
            updateThemeAppearance()
        }

        private func updateThemeAppearance() {
            gridView.setTheme(theme)
            cellManager.setTheme(theme)
        }

        // MARK: - Layout

        override func layoutSubviews() {
            super.layoutSubviews()

            scrollView.clipsToBounds = false
            scrollView.frame = bounds
            let contentSize = intrinsicContentSize
            scrollView.contentSize = contentSize
            gridView.frame = CGRect(origin: .zero, size: contentSize)

            layoutCells()
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

        private func layoutCells() {
            guard !cellManager.cellSizes.isEmpty, !cellManager.cells.isEmpty else {
                return
            }

            var x: CGFloat = 0
            var y: CGFloat = 0

            for row in 0 ..< numberOfRows {
                for column in 0 ..< numberOfColumns {
                    let index = row * numberOfColumns + column
                    let cellSize = cellManager.cellSizes[index]
                    let cell = cellManager.cells[index]
                    let idealCellSize = cell.intrinsicContentSize

                    cell.frame = .init(
                        x: x + cellPadding + tableViewPadding,
                        y: y + (cellSize.height - idealCellSize.height) / 2 + tableViewPadding,
                        width: ceil(idealCellSize.width),
                        height: ceil(idealCellSize.height)
                    )

                    let columnWidth = widths[column]
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
                in: scrollView,
                cellPadding: cellPadding,
                maximumCellWidth: maximumCellWidth
            )

            widths = cellManager.widths
            heights = cellManager.heights

            gridView.padding = tableViewPadding
            gridView.update(widths: widths, heights: heights)

            // Add header background for first row
            if numberOfRows > 0 {
                gridView.setHeaderRow(true)
            }
        }

        private func processContent(
            input: NSAttributedString,
            replacing occurs: String,
            with replaced: String
        ) -> NSMutableAttributedString {
            let mutableAttributedString = input.mutableCopy() as! NSMutableAttributedString
            let mutableString = mutableAttributedString.mutableString
            while mutableString.contains(occurs) {
                let rangeOfStringToBeReplaced = mutableString.range(of: occurs)
                mutableAttributedString.replaceCharacters(in: rangeOfStringToBeReplaced, with: replaced)
            }
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

    // MARK: - LTXLabelDelegate

    extension TableView: LTXLabelDelegate {
        func ltxLabelSelectionDidChange(_: LTXLabel, selection _: NSRange?) {
            // Reserved for future use
        }

        func ltxLabelDetectedUserEventMovingAtLocation(_: LTXLabel, location _: CGPoint) {
            // Reserved for future use
        }

        func ltxLabelDidTapOnHighlightContent(_ label: LTXLabel, region: LTXHighlightRegion?, location: CGPoint) {
            guard let highlightRegion = region else { return }
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
        private let cellPadding: CGFloat = 10
        private let maximumCellWidth: CGFloat = 200

        // MARK: - UI Components

        private lazy var scrollView: NSScrollView = {
            let sv = NSScrollView()
            sv.hasVerticalScroller = false
            sv.hasHorizontalScroller = false
            sv.drawsBackground = false
            return sv
        }()

        private lazy var gridView: GridView = .init()

        // MARK: - Properties

        private(set) var contents: [Rows] = [] {
            didSet {
                configureCells()
                needsLayout = true
            }
        }

        private var cellManager = TableViewCellManager()
        private var widths: [CGFloat] = []
        private var heights: [CGFloat] = []
        private var theme: MarkdownTheme = .default
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

        func setContents(_ contents: [Rows]) {
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
            guard !contentsEqual(self.contents, builder) else { return }
            self.contents = builder
        }

        func setTheme(_ theme: MarkdownTheme) {
            self.theme = theme
            updateThemeAppearance()
        }

        private func updateThemeAppearance() {
            gridView.setTheme(theme)
            cellManager.setTheme(theme)
        }

        // MARK: - Layout

        override func layout() {
            super.layout()

            scrollView.frame = bounds
            gridView.frame = CGRect(origin: .zero, size: intrinsicContentSize)

            layoutCells()
        }

        func interactionTarget(at point: CGPoint) -> NSView? {
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
            guard !isHidden, bounds.contains(point) else { return nil }
            return interactionTarget(at: point)
        }

        private func layoutCells() {
            guard !cellManager.cellSizes.isEmpty, !cellManager.cells.isEmpty else {
                return
            }

            var x: CGFloat = 0
            var y: CGFloat = 0

            for row in 0 ..< numberOfRows {
                for column in 0 ..< numberOfColumns {
                    let index = row * numberOfColumns + column
                    let cellSize = cellManager.cellSizes[index]
                    let cell = cellManager.cells[index]
                    let idealCellSize = cell.intrinsicContentSize

                    cell.frame = .init(
                        x: x + cellPadding + tableViewPadding,
                        y: y + (cellSize.height - idealCellSize.height) / 2 + tableViewPadding,
                        width: ceil(idealCellSize.width),
                        height: ceil(idealCellSize.height)
                    )

                    let columnWidth = widths[column]
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
                in: scrollView.documentView ?? self,
                cellPadding: cellPadding,
                maximumCellWidth: maximumCellWidth
            )

            widths = cellManager.widths
            heights = cellManager.heights

            gridView.padding = tableViewPadding
            gridView.update(widths: widths, heights: heights)

            if numberOfRows > 0 {
                gridView.setHeaderRow(true)
            }
        }

        private func processContent(
            input: NSAttributedString,
            replacing occurs: String,
            with replaced: String
        ) -> NSMutableAttributedString {
            let mutableAttributedString = input.mutableCopy() as! NSMutableAttributedString
            let mutableString = mutableAttributedString.mutableString
            while mutableString.contains(occurs) {
                let rangeOfStringToBeReplaced = mutableString.range(of: occurs)
                mutableAttributedString.replaceCharacters(in: rangeOfStringToBeReplaced, with: replaced)
            }
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

    // MARK: - LTXLabelDelegate

    extension TableView: LTXLabelDelegate {
        func ltxLabelSelectionDidChange(_: LTXLabel, selection _: NSRange?) {}

        func ltxLabelDetectedUserEventMovingAtLocation(_: LTXLabel, location _: CGPoint) {}

        func ltxLabelDidTapOnHighlightContent(_ label: LTXLabel, region: LTXHighlightRegion?, location: CGPoint) {
            guard let highlightRegion = region else { return }
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
