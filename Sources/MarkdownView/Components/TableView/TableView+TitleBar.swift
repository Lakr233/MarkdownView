//
//  TableView+TitleBar.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The text of a table's title bar and of its buttons.
enum TableTitleText {
    static var table: String {
        String(localized: "Table", bundle: .module, comment: "Title of a table's bar.")
    }

    /// The title of a table that leaves `hiddenRowCount` rows out.
    static func table(hiddenRowCount: Int) -> String {
        String(
            localized: "Table (\(hiddenRowCount) more rows not shown)",
            bundle: .module,
            comment: "Title of a long table's bar, counting the rows it does not draw."
        )
    }

    static var copy: String {
        String(localized: "Copy", bundle: .module, comment: "Button that copies a table or a code block.")
    }

    static var download: String {
        String(
            localized: "Download",
            bundle: .module,
            comment: "Button that saves a table or a code block as a file."
        )
    }

    static var expand: String {
        String(
            localized: "Expand",
            bundle: .module,
            comment: "Button that opens a table or a code block in a sheet."
        )
    }
}

#if canImport(UIKit)
    /// The name at the leading end of a table's title bar.
    final class TableTitleLabel: UILabel {
        private var theme: MarkdownTheme = .default

        override init(frame: CGRect) {
            super.init(frame: frame)
            numberOfLines = 1
            lineBreakMode = .byTruncatingTail
            textColor = .secondaryLabel
            setTheme(.default)
            text = TableTitleText.table
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setTheme(_ theme: MarkdownTheme) {
            self.theme = theme
            font = theme.fonts.footnote
        }

        /// The bar's height: one line of the title and the bar's padding.
        var barHeight: CGFloat {
            ceil(theme.fonts.footnote.lineHeight) + TableTitleBar.verticalPadding * 2
        }

        func setHiddenRowCount(_ count: Int) {
            let title = count > 0 ? TableTitleText.table(hiddenRowCount: count) : TableTitleText.table
            if text != title {
                text = title
            }
        }
    }

#elseif canImport(AppKit)
    /// The name at the leading end of a table's title bar.
    final class TableTitleLabel: NSTextField {
        private var theme: MarkdownTheme = .default

        override init(frame: CGRect) {
            super.init(frame: frame)
            isEditable = false
            isSelectable = false
            isBordered = false
            drawsBackground = false
            lineBreakMode = .byTruncatingTail
            maximumNumberOfLines = 1
            cell?.truncatesLastVisibleLine = true
            textColor = .secondaryLabelColor
            setTheme(.default)
            stringValue = TableTitleText.table
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setTheme(_ theme: MarkdownTheme) {
            self.theme = theme
            font = theme.fonts.footnote
        }

        /// The bar's height: one line of the title and the bar's padding.
        var barHeight: CGFloat {
            let font = theme.fonts.footnote
            return ceil(font.ascender + abs(font.descender) + font.leading) + TableTitleBar.verticalPadding * 2
        }

        func setHiddenRowCount(_ count: Int) {
            let title = count > 0 ? TableTitleText.table(hiddenRowCount: count) : TableTitleText.table
            if stringValue != title {
                stringValue = title
            }
        }

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }
#endif

enum TableTitleBar {
    static let verticalPadding: CGFloat = 8
    /// Each button's width, shared by tables and code blocks. Narrow enough
    /// that the glyphs read as one group; the button stays full height.
    #if canImport(UIKit)
        static let buttonWidth: CGFloat = 32
    #elseif canImport(AppKit)
        static let buttonWidth: CGFloat = 24
    #endif
    /// How long Copy shows a checkmark after it is tapped.
    static let copyFeedbackDuration: TimeInterval = 1.5
}

extension TableView {
    func makeTitleControl(symbol: String, title: String, handler: @escaping () -> Void) -> TableTapControl {
        let control = TableTapControl()
        control.setSymbol(symbol)
        control.setAccessibleTitle(title)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            control.toolTip = title
        #endif
        control.handler = handler
        return control
    }

    /// The title at the leading end and Download, Copy and Expand at the
    /// trailing end, inside the bar above the rows. A button the bar has no
    /// room for is hidden — Download first, then Copy — rather than drawn
    /// past the table's edge, where no tap could reach it.
    func layoutTitleBar() {
        guard mode == .inline else { return }
        let height = titleHeight
        let glyph = TableHeaderAccessory.glyphSize
        let leading = tableViewPadding + layoutMetrics.horizontalCellPadding
        var trailing = bounds.width - tableViewPadding - 4
        for control in [expandControl, copyControl, downloadControl] {
            control.isHidden = trailing - TableTitleBar.buttonWidth < leading
            guard !control.isHidden else { continue }
            trailing -= TableTitleBar.buttonWidth
            control.applyFrame(CGRect(x: trailing, y: tableViewPadding, width: TableTitleBar.buttonWidth, height: height))
            control.glyphFrame = CGRect(
                x: (TableTitleBar.buttonWidth - glyph) / 2,
                y: (height - glyph) / 2,
                width: glyph,
                height: glyph
            )
        }
        let labelHeight = titleLabel.intrinsicContentSize.height
        titleLabel.applyFrame(CGRect(
            x: leading,
            y: tableViewPadding + (height - labelHeight) / 2,
            width: max(0, trailing - leading),
            height: labelHeight
        ))
    }

    /// Every row as plain text, header first.
    var plainTextRows: [[String]] {
        contents.map { $0.map(TableExport.plainText) }
    }

    /// Every row, drawn or not, as a Markdown table: written back from the
    /// parsed rows, so links, code, emphasis and math survive, or from the
    /// cells' text for a table given only those.
    func markdown() -> String {
        let rows: [[String]] = if let sourceRows,
                                  sourceRows.count == contents.count,
                                  zip(sourceRows, contents).allSatisfy({ $0.cells.count == $1.count })
        {
            sourceRows.map { $0.cells.map { TableExport.markdownSource($0.content) } }
        } else {
            plainTextRows
        }
        return TableExport.markdown(rows: rows, alignments: columnAlignments)
    }

    func copyTable() {
        FileExporter.copy(markdown())
        #if canImport(UIKit) && !os(visionOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        copyControl.setSymbol(TableSymbol.copied)
        schedule(#selector(resetTableCopyFeedback), after: TableTitleBar.copyFeedbackDuration)
    }

    @objc func resetTableCopyFeedback() {
        cancelScheduled(#selector(resetTableCopyFeedback))
        copyControl.setSymbol(TableSymbol.copy)
    }

    func downloadTable() {
        FileExporter.export(TableExport.csvData(rows: plainTextRows), fileName: "table.csv", from: self)
    }
}
