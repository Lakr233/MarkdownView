//
//  TableSheet.swift
//  MarkdownView
//

import Foundation
import Litext
import MarkdownParser

/// What the full-table sheet is built from: the rows of the table it was
/// opened from at that moment, every one of them.
struct TableSheetContent {
    let contents: [[NSAttributedString]]
    let columnAlignments: [RawTableColumnAlignment]
    let theme: MarkdownTheme
    let linkHandler: ((LinkPayload, NSRange, CGPoint) -> Void)?
    /// Every row as Markdown, as Copy puts it on the pasteboard.
    let markdown: String
    /// Every row as CSV, as Download saves it.
    let csv: Data

    @MainActor
    init(_ tableView: TableView) {
        contents = tableView.contents
        columnAlignments = tableView.columnAlignments
        theme = tableView.currentTheme
        linkHandler = tableView.linkHandler
        markdown = tableView.markdown()
        csv = TableExport.csvData(rows: tableView.plainTextRows)
    }

    /// Copy, Download and Close for the sheet showing this table from `view`.
    @MainActor
    func menuActions(from view: @escaping () -> PlatformView?, close: @escaping () -> Void) -> SheetMenuActions {
        let markdown = markdown
        let csv = csv
        return SheetMenuActions(
            copy: {
                FileExporter.copy(markdown)
                #if canImport(UIKit) && !os(visionOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            },
            download: {
                guard let view = view() else { return }
                FileExporter.export(csv, fileName: "table.csv", from: view)
            },
            close: close,
        )
    }

    /// A table in sheet mode showing every row.
    @MainActor
    func makeTableView() -> TableView {
        let tableView = TableView(mode: .sheet)
        tableView.setTheme(theme)
        tableView.setContents(contents, columnAlignments: columnAlignments)
        tableView.linkHandler = linkHandler
        return tableView
    }
}

// UIKit shows the sheet in TableSheetViewController.
#if canImport(AppKit) && !canImport(UIKit)
    import AppKit

    @MainActor
    enum TableSheetPresenter {
        /// Presents every row of `tableView` in a sheet on its window.
        static func present(_ tableView: TableView) {
            guard let window = tableView.window else { return }
            let sheet = TableSheetWindow(content: TableSheetContent(tableView))
            window.beginSheet(sheet)
        }
    }

    /// Every row of a table, scrolling both ways, sortable by its header.
    final class TableSheetWindow: NSWindow {
        let tableView: TableView

        init(content: TableSheetContent) {
            tableView = content.makeTableView()
            let margin = TableSheetContentView.margin
            let size = CGSize(
                width: min(960, max(420, tableView.naturalContentWidth + margin * 2)),
                height: min(720, max(240, tableView.intrinsicContentHeight + margin * 2 + TableSheetContentView.barHeight)),
            )
            super.init(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: false,
            )
            isReleasedWhenClosed = false
            minSize = CGSize(width: 320, height: 200)
            let contentView = TableSheetContentView(tableView: tableView)
            self.contentView = contentView
            contentView.installMenu(content.menuActions(
                from: { [weak contentView] in contentView },
                close: { [weak self] in self?.close(nil) },
            ))
            tableView.sortHandler = { [weak contentView] _ in
                contentView?.needsLayout = true
            }
        }

        override func cancelOperation(_: Any?) {
            close(nil)
        }

        @objc private func close(_: Any?) {
            if let parent = sheetParent {
                parent.endSheet(self)
            } else {
                orderOut(nil)
            }
        }
    }

    private final class TableSheetContentView: NSView {
        static let margin: CGFloat = 16
        static let barHeight: CGFloat = 48

        private var menuButton: SheetMenuButton?
        private let scrollView = NSScrollView()
        private let documentView = FlippedView()
        private let tableView: TableView

        init(tableView: TableView) {
            self.tableView = tableView
            super.init(frame: .zero)
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.drawsBackground = false
            scrollView.documentView = documentView
            documentView.addSubview(tableView)
            addSubview(scrollView)
        }

        func installMenu(_ actions: SheetMenuActions) {
            menuButton?.removeFromSuperview()
            let button = SheetMenuButton(actions: actions)
            addSubview(button)
            menuButton = button
            needsLayout = true
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            let margin = Self.margin
            // Not flipped: the bar holding the menu is the top band.
            scrollView.frame = CGRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: max(0, bounds.height - Self.barHeight),
            )
            if let menuButton {
                menuButton.frame.origin = CGPoint(
                    x: bounds.width - margin - menuButton.frame.width,
                    y: bounds.height - Self.barHeight + (Self.barHeight - menuButton.frame.height) / 2,
                )
            }
            let width = max(0, scrollView.contentSize.width - margin * 2)
            let height = tableView.intrinsicContentHeight
            documentView.frame = CGRect(
                x: 0,
                y: 0,
                width: scrollView.contentSize.width,
                height: max(scrollView.contentSize.height, height + margin * 2),
            )
            tableView.frame = CGRect(x: margin, y: margin, width: width, height: height)
        }
    }

    private final class FlippedView: NSView {
        override var isFlipped: Bool {
            true
        }
    }
#endif
