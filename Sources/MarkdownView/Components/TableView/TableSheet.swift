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

    @MainActor
    init(_ tableView: TableView) {
        contents = tableView.contents
        columnAlignments = tableView.columnAlignments
        theme = tableView.currentTheme
        linkHandler = tableView.linkHandler
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

#if canImport(UIKit)
    import UIKit

    @MainActor
    enum TableSheetPresenter {
        /// Presents every row of `tableView` in a full-height sheet over the
        /// view controller showing it.
        static func present(_ tableView: TableView) {
            guard let presenter = tableView.topPresentingViewController else { return }
            let controller = TableSheetViewController(content: TableSheetContent(tableView))
            controller.title = TableTitleText.table
            let navigation = UINavigationController(rootViewController: controller)
            navigation.modalPresentationStyle = .pageSheet
            presenter.present(navigation, animated: true)
        }
    }

    /// Every row of a table, scrolling both ways, sortable by its header.
    final class TableSheetViewController: UIViewController {
        private static let margin: CGFloat = 16

        let tableView: TableView
        private let scrollView = UIScrollView()

        init(content: TableSheetContent) {
            tableView = content.makeTableView()
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            scrollView.alwaysBounceVertical = true
            scrollView.backgroundColor = .clear
            view.addSubview(scrollView)
            scrollView.addSubview(tableView)
            tableView.sortHandler = { [weak self] _ in
                self?.view.setNeedsLayout()
            }
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(close)
            )
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            scrollView.frame = view.bounds
            let insets = view.safeAreaInsets
            let width = max(0, view.bounds.width - insets.left - insets.right - Self.margin * 2)
            let height = tableView.intrinsicContentHeight
            tableView.frame = CGRect(
                x: insets.left + Self.margin,
                y: Self.margin,
                width: width,
                height: height
            )
            scrollView.contentSize = CGSize(
                width: scrollView.bounds.width - insets.left - insets.right,
                height: height + Self.margin * 2
            )
        }

        @objc private func close() {
            dismiss(animated: true)
        }
    }

#elseif canImport(AppKit)
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
                height: min(720, max(240, tableView.intrinsicContentHeight + margin * 2 + TableSheetContentView.barHeight))
            )
            super.init(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: false
            )
            isReleasedWhenClosed = false
            minSize = CGSize(width: 320, height: 200)
            let contentView = TableSheetContentView(tableView: tableView)
            contentView.closeButton.target = self
            contentView.closeButton.action = #selector(close(_:))
            self.contentView = contentView
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

        let closeButton = NSButton(title: TableSheetText.done, target: nil, action: nil)
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
            closeButton.bezelStyle = .rounded
            closeButton.keyEquivalent = "\r"
            addSubview(closeButton)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            let margin = Self.margin
            scrollView.frame = CGRect(
                x: 0,
                y: Self.barHeight,
                width: bounds.width,
                height: max(0, bounds.height - Self.barHeight)
            )
            closeButton.sizeToFit()
            closeButton.frame.origin = CGPoint(
                x: bounds.width - margin - closeButton.frame.width,
                y: (Self.barHeight - closeButton.frame.height) / 2
            )
            let width = max(0, scrollView.contentSize.width - margin * 2)
            let height = tableView.intrinsicContentHeight
            documentView.frame = CGRect(
                x: 0,
                y: 0,
                width: scrollView.contentSize.width,
                height: max(scrollView.contentSize.height, height + margin * 2)
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
