//
//  TableViewCellManager.swift
//  MarkdownView
//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext

#if canImport(UIKit)
    import UIKit

    @MainActor
    final class TableViewCellManager {
        // MARK: - Properties

        private(set) var cells: [TextLabelView] = []
        private var rawTexts: [NSAttributedString] = []
        private(set) var cellSizes: [CGSize] = []
        private(set) var widths: [CGFloat] = []
        private(set) var heights: [CGFloat] = []
        private var theme: MarkdownTheme = .default
        private weak var delegate: TextLabelViewDelegate?

        // MARK: - Cell Configuration

        func configureCells(
            for contents: [[NSAttributedString]],
            in containerView: UIView,
            cellPadding: CGFloat,
            maximumCellWidth: CGFloat
        ) {
            let numberOfRows = contents.count
            let numberOfColumns = contents.first?.count ?? 0
            let requiredCellCount = contents.reduce(0) { $0 + $1.count }

            cellSizes = Array(repeating: .zero, count: numberOfRows * numberOfColumns)
            widths = Array(repeating: 0, count: numberOfColumns)
            heights = Array(repeating: 0, count: numberOfRows)
            trimSurplusCells(keeping: requiredCellCount)

            for (row, rowContent) in contents.enumerated() {
                var rowHeight: CGFloat = 0

                for (column, cellString) in rowContent.enumerated() {
                    let index = row * rowContent.count + column
                    let isHeaderCell = row == 0
                    let cell = createOrUpdateCell(
                        at: index,
                        with: cellString,
                        maximumWidth: maximumCellWidth,
                        isHeader: isHeaderCell,
                        in: containerView
                    )

                    let cellSize = calculateCellSize(for: cell, cellPadding: cellPadding)
                    cellSizes[index] = cellSize

                    // Update row and column dimensions
                    rowHeight = max(rowHeight, cellSize.height)
                    widths[column] = max(widths[column], cellSize.width)
                }

                heights[row] = rowHeight
            }
        }

        // MARK: - Public Methods

        func setTheme(_ theme: MarkdownTheme) {
            guard self.theme != theme else { return }
            self.theme = theme
            updateCellsAppearance()
        }

        func setDelegate(_ delegate: TextLabelViewDelegate?) {
            self.delegate = delegate
            cells.forEach { $0.delegate = delegate }
        }

        // MARK: - Private Methods

        private func createOrUpdateCell(
            at index: Int,
            with attributedText: NSAttributedString,
            maximumWidth: CGFloat,
            isHeader: Bool,
            in containerView: UIView
        ) -> TextLabelView {
            let cell: TextLabelView

            if index >= cells.count {
                cell = TextLabelView()
                cell.isSelectable = false
                cell.backgroundColor = .clear
                cell.selectionBackgroundColor = theme.colors.selectionBackground
                cell.delegate = delegate
                containerView.addSubview(cell)
                cells.append(cell)
            } else {
                cell = cells[index]
            }

            let needsTextUpdate = cell.preferredMaxLayoutWidth != maximumWidth
                || index >= rawTexts.count
                || !rawTexts[index].isEqual(to: attributedText)
            if needsTextUpdate {
                if index < rawTexts.count {
                    rawTexts[index] = attributedText
                } else {
                    rawTexts.append(attributedText)
                }
                cell.preferredMaxLayoutWidth = maximumWidth
                cell.attributedText = isHeader
                    ? styledHeaderText(from: attributedText)
                    : styledNormalText(from: attributedText)
            }

            return cell
        }

        private func trimSurplusCells(keeping requiredCellCount: Int) {
            guard cells.count > requiredCellCount else { return }
            for index in stride(from: cells.count - 1, through: requiredCellCount, by: -1) {
                cells[index].removeFromSuperview()
                cells.remove(at: index)
                if index < rawTexts.count {
                    rawTexts.remove(at: index)
                }
            }
        }

        private func calculateCellSize(for cell: TextLabelView, cellPadding: CGFloat) -> CGSize {
            let contentSize = cell.intrinsicContentSize
            return CGSize(
                width: ceil(contentSize.width) + cellPadding * 2,
                height: ceil(contentSize.height) + cellPadding * 2
            )
        }

        private func styledHeaderText(from source: NSAttributedString) -> NSAttributedString {
            guard let attributedText = source.mutableCopy() as? NSMutableAttributedString else {
                return source
            }
            let range = NSRange(location: 0, length: attributedText.length)

            attributedText.enumerateAttribute(.font, in: range, options: []) {
                value, subRange, _ in
                if let existingFont = value as? UIFont {
                    let boldFont = UIFont.boldSystemFont(ofSize: existingFont.pointSize)
                    attributedText.addAttribute(.font, value: boldFont, range: subRange)
                } else {
                    attributedText.addAttribute(.font, value: theme.fonts.bold, range: subRange)
                }
            }

            return attributedText
        }

        private func styledNormalText(from source: NSAttributedString) -> NSAttributedString {
            guard let attributedText = source.mutableCopy() as? NSMutableAttributedString else {
                return source
            }
            let range = NSRange(location: 0, length: attributedText.length)

            attributedText.enumerateAttribute(.foregroundColor, in: range, options: []) {
                value, subRange, _ in
                if value == nil {
                    attributedText.addAttribute(
                        .foregroundColor, value: theme.colors.body, range: subRange
                    )
                }
            }

            return attributedText
        }

        private func updateCellsAppearance() {
            for (index, cell) in cells.enumerated() {
                cell.selectionBackgroundColor = theme.colors.selectionBackground
                let numberOfColumns = widths.count
                let row = index / numberOfColumns
                let isHeaderCell = row == 0

                let source = index < rawTexts.count ? rawTexts[index] : cell.attributedText
                let styled = isHeaderCell
                    ? styledHeaderText(from: source)
                    : styledNormalText(from: source)
                if !styled.isEqual(to: cell.attributedText) {
                    cell.attributedText = styled
                }
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    @MainActor
    final class TableViewCellManager {
        private(set) var cells: [TextLabelView] = []
        private var rawTexts: [NSAttributedString] = []
        private(set) var cellSizes: [CGSize] = []
        private(set) var widths: [CGFloat] = []
        private(set) var heights: [CGFloat] = []
        private var theme: MarkdownTheme = .default
        private weak var delegate: TextLabelViewDelegate?

        func configureCells(
            for contents: [[NSAttributedString]],
            in containerView: NSView,
            cellPadding: CGFloat,
            maximumCellWidth: CGFloat
        ) {
            let numberOfRows = contents.count
            let numberOfColumns = contents.first?.count ?? 0
            let requiredCellCount = contents.reduce(0) { $0 + $1.count }

            cellSizes = Array(repeating: .zero, count: numberOfRows * numberOfColumns)
            widths = Array(repeating: 0, count: numberOfColumns)
            heights = Array(repeating: 0, count: numberOfRows)
            trimSurplusCells(keeping: requiredCellCount)

            for (row, rowContent) in contents.enumerated() {
                var rowHeight: CGFloat = 0

                for (column, cellString) in rowContent.enumerated() {
                    let index = row * rowContent.count + column
                    let isHeaderCell = row == 0
                    let cell = createOrUpdateCell(
                        at: index,
                        with: cellString,
                        maximumWidth: maximumCellWidth,
                        isHeader: isHeaderCell,
                        in: containerView
                    )

                    let cellSize = calculateCellSize(for: cell, cellPadding: cellPadding)
                    cellSizes[index] = cellSize

                    rowHeight = max(rowHeight, cellSize.height)
                    widths[column] = max(widths[column], cellSize.width)
                }

                heights[row] = rowHeight
            }
        }

        func setTheme(_ theme: MarkdownTheme) {
            guard self.theme != theme else { return }
            self.theme = theme
            updateCellsAppearance()
        }

        func setDelegate(_ delegate: TextLabelViewDelegate?) {
            self.delegate = delegate
            cells.forEach { $0.delegate = delegate }
        }

        private func createOrUpdateCell(
            at index: Int,
            with attributedText: NSAttributedString,
            maximumWidth: CGFloat,
            isHeader: Bool,
            in containerView: NSView
        ) -> TextLabelView {
            let cell: TextLabelView

            if index >= cells.count {
                cell = TextLabelView()
                cell.isSelectable = false
                cell.wantsLayer = true
                cell.layer?.backgroundColor = NSColor.clear.cgColor
                cell.selectionBackgroundColor = theme.colors.selectionBackground
                cell.delegate = delegate
                containerView.addSubview(cell)
                cells.append(cell)
            } else {
                cell = cells[index]
            }

            let needsTextUpdate = cell.preferredMaxLayoutWidth != maximumWidth
                || index >= rawTexts.count
                || !rawTexts[index].isEqual(to: attributedText)
            if needsTextUpdate {
                if index < rawTexts.count {
                    rawTexts[index] = attributedText
                } else {
                    rawTexts.append(attributedText)
                }
                cell.preferredMaxLayoutWidth = maximumWidth
                cell.attributedText = isHeader
                    ? styledHeaderText(from: attributedText)
                    : styledNormalText(from: attributedText)
            }

            return cell
        }

        private func trimSurplusCells(keeping requiredCellCount: Int) {
            guard cells.count > requiredCellCount else { return }
            for index in stride(from: cells.count - 1, through: requiredCellCount, by: -1) {
                cells[index].removeFromSuperview()
                cells.remove(at: index)
                if index < rawTexts.count {
                    rawTexts.remove(at: index)
                }
            }
        }

        private func calculateCellSize(for cell: TextLabelView, cellPadding: CGFloat) -> CGSize {
            let contentSize = cell.intrinsicContentSize
            return CGSize(
                width: ceil(contentSize.width) + cellPadding * 2,
                height: ceil(contentSize.height) + cellPadding * 2
            )
        }

        private func styledHeaderText(from source: NSAttributedString) -> NSAttributedString {
            guard let attributedText = source.mutableCopy() as? NSMutableAttributedString else {
                return source
            }
            let range = NSRange(location: 0, length: attributedText.length)

            attributedText.enumerateAttribute(.font, in: range, options: []) {
                value, subRange, _ in
                if let existingFont = value as? NSFont {
                    let boldFont = NSFont.boldSystemFont(ofSize: existingFont.pointSize)
                    attributedText.addAttribute(.font, value: boldFont, range: subRange)
                } else {
                    attributedText.addAttribute(.font, value: theme.fonts.bold, range: subRange)
                }
            }

            return attributedText
        }

        private func styledNormalText(from source: NSAttributedString) -> NSAttributedString {
            guard let attributedText = source.mutableCopy() as? NSMutableAttributedString else {
                return source
            }
            let range = NSRange(location: 0, length: attributedText.length)

            attributedText.enumerateAttribute(.foregroundColor, in: range, options: []) {
                value, subRange, _ in
                if value == nil {
                    attributedText.addAttribute(
                        .foregroundColor, value: theme.colors.body, range: subRange
                    )
                }
            }

            return attributedText
        }

        private func updateCellsAppearance() {
            for (index, cell) in cells.enumerated() {
                cell.selectionBackgroundColor = theme.colors.selectionBackground
                let numberOfColumns = widths.count
                let row = index / numberOfColumns
                let isHeaderCell = row == 0

                let source = index < rawTexts.count ? rawTexts[index] : cell.attributedText
                let styled = isHeaderCell
                    ? styledHeaderText(from: source)
                    : styledNormalText(from: source)
                if !styled.isEqual(to: cell.attributedText) {
                    cell.attributedText = styled
                }
            }
        }
    }
#endif
