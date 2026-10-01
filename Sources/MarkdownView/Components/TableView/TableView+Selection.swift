//
//  TableView+Selection.swift
//  MarkdownView
//

import Litext

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A cell's place among the rows a table draws, header first.
struct TableCellPosition: Equatable {
    let row: Int
    let column: Int
}

extension TableView {
    /// Joins the cells of a row with a tab and rows with a line break, so
    /// copied cells paste into a spreadsheet in place.
    func configureSelectionGroup() {
        selectionGroup.delegate = self
        selectionGroup.separator = { [weak self] previous, next in
            let positions = self?.cellPositions
            let previousRow = positions?[ObjectIdentifier(previous)]?.row
            let nextRow = positions?[ObjectIdentifier(next)]?.row
            return previousRow != nil && previousRow == nextRow ? "\t" : "\n"
        }
    }

    /// Puts the cells drawn into the group, in reading order.
    ///
    /// The group is only given a new list when the cells themselves change,
    /// since that clears its selection. A stream that edits a cell's text
    /// keeps the cells, so a selection elsewhere in the table survives it.
    func updateSelectionGroup() {
        let cells = cellViews
        let columns = max(1, display.rows.first?.count ?? 1)
        cellPositions = Dictionary(
            uniqueKeysWithValues: cells.enumerated().map { index, cell in
                (ObjectIdentifier(cell), TableCellPosition(row: index / columns, column: index % columns))
            }
        )
        guard !selectionGroup.labels.elementsEqual(cells, by: ===) else { return }
        selectionGroup.labels = cells
    }

    /// The selected cells as a Markdown table.
    ///
    /// It spans the columns the selection touches. A selection that starts
    /// below the header still gets the header of those columns, so what is
    /// pasted is a table; a cell the selection skips is left empty.
    func selectedMarkdown() -> String? {
        var selected: [Int: [Int: String]] = [:]
        for segment in selectionGroup.selectedSegments {
            guard let position = cellPositions[ObjectIdentifier(segment.label)] else { continue }
            let text = segment.label.selectedAttributedText()?.string ?? ""
            selected[position.row, default: [:]][position.column] = text
        }
        let columns = selected.values.flatMap(\.keys)
        guard let firstColumn = columns.min(), let lastColumn = columns.max() else { return nil }
        let columnRange = firstColumn ... lastColumn

        var rows = selected.keys.sorted().map { row in
            columnRange.map { selected[row]?[$0] ?? "" }
        }
        if selected[0] == nil, let header = display.rows.first {
            rows.insert(columnRange.map { header[safe: $0]?.string ?? "" }, at: 0)
        }

        func line(_ cells: [String]) -> String {
            "| " + cells.map(Self.markdownCell).joined(separator: " | ") + " |"
        }
        var lines = rows.map(line)
        let delimiters = columnRange.map { column -> String in
            switch columnAlignments[safe: column] {
            case .left: ":---"
            case .center: ":---:"
            case .right: "---:"
            case .none?, nil: "---"
            }
        }
        lines.insert("| " + delimiters.joined(separator: " | ") + " |", at: 1)
        return lines.joined(separator: "\n")
    }

    /// A cell's text as it reads inside a Markdown table row.
    private static func markdownCell(_ text: String) -> String {
        text
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: "<br>")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    fileprivate static var copyAsMarkdownTitle: String {
        String(
            localized: "Copy as Markdown",
            bundle: .module,
            comment: "Menu command that copies the selected table cells as a Markdown table."
        )
    }
}

// MARK: - TextSelectionGroupDelegate

extension TableView: TextSelectionGroupDelegate {
    func textSelectionGroup(
        _: TextSelectionGroup,
        didDragSelectionIn label: TextLabelView,
        at location: CGPoint
    ) {
        scrollHorizontally(toFollowDragAt: location, in: label)
        textSelectionDelegate?.textLabelView(label, didDragSelectionAt: location)
    }

    #if canImport(UIKit)
        @available(iOS 16.0, macCatalyst 16.0, visionOS 1.0, *)
        func textSelectionGroup(
            _: TextSelectionGroup,
            editMenuForSuggestedActions suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let copyAsMarkdown = UIAction(
                title: Self.copyAsMarkdownTitle,
                image: UIImage(systemName: "tablecells")
            ) { [weak self] _ in
                guard let markdown = self?.selectedMarkdown() else { return }
                UIPasteboard.general.string = markdown
            }
            return UIMenu(children: suggestedActions + [copyAsMarkdown])
        }

    #elseif canImport(AppKit)
        func textSelectionGroup(_: TextSelectionGroup, menu: NSMenu, event _: NSEvent) -> NSMenu? {
            let item = NSMenuItem(
                title: Self.copyAsMarkdownTitle,
                action: #selector(copySelectionAsMarkdown(_:)),
                keyEquivalent: ""
            )
            item.target = self
            let copyIndex = menu.items.firstIndex { $0.action == #selector(NSText.copy(_:)) }
            menu.insertItem(item, at: copyIndex.map { $0 + 1 } ?? 0)
            return menu
        }

        @objc func copySelectionAsMarkdown(_: Any?) {
            guard let markdown = selectedMarkdown() else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(markdown, forType: .string)
        }
    #endif
}

// MARK: - Horizontal Autoscroll

private let dragEdgeWidth: CGFloat = 16

#if canImport(UIKit)
    private extension TableView {
        /// Scrolls the columns sideways while a drag runs past either edge.
        func scrollHorizontally(toFollowDragAt location: CGPoint, in label: TextLabelView) {
            guard let scrollView = label.superview as? UIScrollView,
                  scrollView.contentSize.width > scrollView.bounds.width
            else { return }
            let point = label.convert(location, to: scrollView)
            let visible = scrollView.bounds.insetBy(dx: dragEdgeWidth, dy: 0)
            var offset = scrollView.contentOffset
            if point.x < visible.minX {
                offset.x -= visible.minX - point.x
            } else if point.x > visible.maxX {
                offset.x += point.x - visible.maxX
            } else {
                return
            }
            offset.x = min(max(0, offset.x), scrollView.contentSize.width - scrollView.bounds.width)
            scrollView.setContentOffset(offset, animated: false)
        }
    }

#elseif canImport(AppKit)
    private extension TableView {
        /// Scrolls the columns sideways while a drag runs past either edge.
        func scrollHorizontally(toFollowDragAt location: CGPoint, in label: TextLabelView) {
            guard let scrollView = label.enclosingScrollView,
                  let documentView = scrollView.documentView,
                  documentView.bounds.width > scrollView.bounds.width
            else { return }
            let point = label.convert(location, to: documentView)
            let visible = scrollView.documentVisibleRect.insetBy(dx: dragEdgeWidth, dy: 0)
            var origin = scrollView.documentVisibleRect.origin
            if point.x < visible.minX {
                origin.x -= visible.minX - point.x
            } else if point.x > visible.maxX {
                origin.x += point.x - visible.maxX
            } else {
                return
            }
            let clipView = scrollView.contentView
            let proposed = CGRect(origin: origin, size: clipView.bounds.size)
            clipView.scroll(to: clipView.constrainBoundsRect(proposed).origin)
            scrollView.reflectScrolledClipView(clipView)
        }
    }
#endif
