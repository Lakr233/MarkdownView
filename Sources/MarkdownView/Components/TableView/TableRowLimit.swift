//
//  TableRowLimit.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// How many of a table's rows are drawn inline.
///
/// A long table in a chat answer pushes everything after it off screen, and
/// every one of its cells costs a layout on every streamed token. The inline
/// table keeps its header and the first rows in source order and replaces
/// the rest with one row saying how many there are; the full table opens in
/// a sheet.
struct TableRowLimit: Equatable {
    /// Content rows drawn inline, not counting the header.
    static let maximumVisibleRows = 8

    /// Content rows drawn inline: the first ones, in source order.
    let visibleRowCount: Int
    /// Content rows left out, all of them after the visible ones.
    let hiddenRowCount: Int

    /// `rowCount` counts every row, header included.
    init(rowCount: Int, maximumVisibleRows: Int = Self.maximumVisibleRows) {
        let contentRows = max(0, rowCount - 1)
        visibleRowCount = min(contentRows, max(0, maximumVisibleRows))
        hiddenRowCount = contentRows - visibleRowCount
    }

    var isTruncated: Bool {
        hiddenRowCount > 0
    }

    /// The rows drawn inline: the header and the first visible rows.
    func visibleRows<Row>(of rows: [Row]) -> [Row] {
        Array(rows.prefix(rows.isEmpty ? 0 : 1 + visibleRowCount))
    }
}

/// The text of the row standing in for the rows a truncated table leaves out.
enum TableSummaryText {
    /// "8 more rows hidden", counting exactly `hiddenRowCount`.
    static func hiddenRows(_ hiddenRowCount: Int) -> String {
        String(
            localized: "\(hiddenRowCount) more rows hidden",
            bundle: .module,
            comment: "The last row of a long table, before the View All link."
        )
    }

    static var viewAll: String {
        String(
            localized: "View All",
            bundle: .module,
            comment: "Opens a long table in full. Shown underlined after the hidden-row count."
        )
    }

    static var showFullTable: String {
        String(
            localized: "Show Full Table",
            bundle: .module,
            comment: "Accessibility label of the button that opens a table in full."
        )
    }

    static var done: String {
        String(
            localized: "Done",
            bundle: .module,
            comment: "Closes the full table."
        )
    }

    /// The summary row's text, with View All underlined.
    static func attributedText(hiddenRowCount: Int, theme: MarkdownTheme) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .natural
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.fonts.body,
            .foregroundColor: theme.colors.body,
            .paragraphStyle: paragraph,
        ]
        let text = NSMutableAttributedString(
            string: hiddenRows(hiddenRowCount) + " ",
            attributes: attributes
        )
        var linkAttributes = attributes
        linkAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        text.append(NSAttributedString(string: viewAll, attributes: linkAttributes))
        return text
    }
}

/// The SF Symbols the table's controls draw.
enum TableSymbol {
    /// Outward arrows: open the table in full.
    static let expand = "arrow.down.left.and.arrow.up.right"
    /// The same meaning, for systems whose symbol set predates `expand`.
    static let expandFallback = "arrow.up.left.and.arrow.down.right"
    static let sortAscending = "chevron.up"
    static let sortDescending = "chevron.down"
}

/// Space a header cell gives up at its trailing edge for a control drawn there.
///
/// The column is measured with it, so the control never sits on header text.
enum TableHeaderAccessory {
    /// The glyph's box.
    static let glyphSize: CGFloat = 14
    /// Between the header text and the glyph.
    static let spacing: CGFloat = 6

    static var width: CGFloat {
        glyphSize + spacing
    }
}
