import Litext
import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A table sits in a frame that does not scroll — its border, a title bar
/// naming it with Copy and Expand, and the row backgrounds —
/// while its columns scroll sideways inside. Copy, and Download in the
/// sheet, hand over
/// every row, drawn or not, exactly.
@MainActor
struct TableTitleBarTests {
    private static let table = """
    | Name | Note | Amount |
    | :-- | :-: | --: |
    | `swift test` | a \\| b | 1,200 |
    | "quoted" | two<br>lines | 3 |
    """

    private func tableView(_ markdown: String, width: CGFloat = 480) throws -> (MarkdownTextView, TableView) {
        let view = RenderProbe.view(markdown, width: width)
        let table = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        RenderProbe.layout(view)
        layout(table)
        return (view, table)
    }

    private func layout(_ table: TableView) {
        #if canImport(UIKit)
            table.setNeedsLayout()
            table.layoutIfNeeded()
        #elseif canImport(AppKit)
            table.needsLayout = true
            table.layoutSubtreeIfNeeded()
        #endif
    }

    private func scrollView(of table: TableView) throws -> PlatformScrollView {
        try #require(table.subviews.compactMap { $0 as? PlatformScrollView }.first)
    }

    private func gridView(of table: TableView) throws -> GridView {
        try #require(table.subviews.compactMap { $0 as? GridView }.first)
    }

    // MARK: - Title bar

    @Test("The title bar names the table, and counts the rows a long one leaves out")
    func titleNamesTheTable() throws {
        let (_, short) = try tableView(Self.table)
        #expect(titleText(of: short) == TableTitleText.table)

        let rows = (1 ... 130).map { "| r\($0) | v\($0) |" }.joined(separator: "\n")
        let (_, long) = try tableView("| A | B |\n| - | - |\n" + rows)
        #expect(titleText(of: long) == TableTitleText.table(hiddenRowCount: 110))
        #expect(titleText(of: long).contains("110"))
    }

    @Test("The rows sit below the title bar, and the table is as tall as both")
    func rowsSitBelowTheTitleBar() throws {
        let (_, table) = try tableView(Self.table)
        let barBottom = table.tableViewPadding + table.titleHeight
        #expect(table.titleHeight > 0)
        let scroll = try scrollView(of: table)
        #expect(abs(scroll.frame.minY - barBottom) < 0.001)
        for cell in table.cellViews {
            #expect(cell.convert(cell.bounds, to: table).minY >= barBottom)
        }
        #expect(table.intrinsicContentHeight >= barBottom + scroll.frame.height)
        for control in [table.copyControl, table.expandControl] {
            #expect(control.frame.maxY <= barBottom + 0.5)
            #expect(control.frame.maxX <= table.bounds.width)
        }
        // Copy, then Expand, from left to right.
        #expect(table.copyControl.frame.maxX <= table.expandControl.frame.minX + 0.5)
    }

    @Test("A narrow table hides the buttons it has no room for, never drawing one past its edge", arguments: [
        40 as CGFloat, 80, 120, 200,
    ])
    func narrowTableHidesButtons(width: CGFloat) throws {
        let (_, table) = try tableView(Self.table)
        table.frame.size.width = width
        layout(table)
        let visible = [table.expandControl, table.copyControl].filter { !$0.isHidden }
        for control in visible {
            #expect(control.frame.minX >= table.tableViewPadding)
            #expect(control.frame.maxX <= width)
        }
        // Copy goes first; Expand is the last to go.
        if !visible.isEmpty {
            #expect(!table.expandControl.isHidden)
        }
    }

    @Test("In the sheet, a tap on a header reaches its sort control")
    func sheetSortControlsAreHittable() throws {
        let (_, inline) = try tableView(Self.table)
        let sheet = TableSheetContent(inline).makeTableView()
        sheet.frame = CGRect(x: 0, y: 0, width: 480, height: sheet.intrinsicContentHeight)
        layout(sheet)
        #expect(sheet.sortControls.count == 3)
        for (column, control) in sheet.sortControls.enumerated() {
            let header = sheet.cellViews[column]
            let frame = header.convert(header.bounds, to: sheet)
            #expect(sheet.interactionTarget(at: CGPoint(x: frame.midX, y: frame.midY)) === control)
        }
    }

    @Test("Taps on the title bar's buttons reach them")
    func titleButtonsAreHittable() throws {
        let (_, table) = try tableView(Self.table)
        for control in [table.copyControl, table.expandControl] {
            let center = CGPoint(x: control.frame.midX, y: control.frame.midY)
            #expect(table.interactionTarget(at: center) === control)
        }
    }

    @Test("Expand opens the full table")
    func expandOpensTheFullTable() throws {
        let (_, table) = try tableView(Self.table)
        var opened: [TableView] = []
        table.expandHandler = { opened.append($0) }
        table.expandControl.performTap()
        #expect(opened.count == 1 && opened.first === table)
    }

    @Test("The sheet copies the table as Markdown and saves it as CSV")
    func sheetCopiesAndSavesTheTable() throws {
        let (_, table) = try tableView(Self.table)
        let content = TableSheetContent(table)
        #expect(content.markdown == table.markdown())
        #expect(content.csv == TableExport.csvData(rows: table.plainTextRows))
    }

    @Test("The sheet's table has no title bar")
    func sheetTableHasNoTitleBar() throws {
        let (_, table) = try tableView(Self.table)
        let sheet = TableSheetContent(table).makeTableView()
        #expect(sheet.titleHeight == 0)
        #expect(sheet.copyControl.superview == nil)
    }

    // MARK: - Frame and scrolling

    @Test("The frame stays put and the column lines follow the scroll")
    func columnLinesFollowTheScroll() throws {
        let markdown = """
        | Column one | Column two | Column three | Column four | Column five |
        | - | - | - | - | - |
        | a considerably long cell | b considerably long cell | c | d | e |
        """
        let (_, table) = try tableView(markdown, width: 300)
        let grid = try gridView(of: table)
        let scroll = try scrollView(of: table)
        #expect(grid.frame == table.bounds)
        #expect(scroll.frame.minX >= table.tableViewPadding)
        #expect(scroll.frame.maxX <= table.bounds.width - table.tableViewPadding)

        let before = grid.columnLinePositions
        #if canImport(UIKit)
            scroll.contentOffset.x = 40
        #elseif canImport(AppKit)
            scroll.contentView.scroll(to: CGPoint(x: 40, y: 0))
            scroll.reflectScrolledClipView(scroll.contentView)
            #expect(!scroll.hasHorizontalScroller && !scroll.hasVerticalScroller)
        #endif
        let after = grid.columnLinePositions
        #expect(before.count == 4)
        #expect(zip(before, after).allSatisfy { abs($0 - $1 - 40) < 0.001 })
        #expect(grid.frame == table.bounds)
    }

    // MARK: - Export

    @Test("Copy gives every row as the Markdown it was written in")
    func copyGivesMarkdown() throws {
        let (_, table) = try tableView(Self.table)
        #expect(table.markdown() == """
        | Name | Note | Amount |
        | :--- | :---: | ---: |
        | `swift test` | a \\| b | 1,200 |
        | "quoted" | two<br>lines | 3 |
        """)
    }

    @Test("Copied Markdown parses back to the same table", arguments: [
        """
        | Kind | Example | Value |
        | :-- | :-: | --: |
        | link | [site](https://example.com/a?b=1&c=2) | **bold** and *it* |
        | code | `a|b` and ``x`y`` | ~~gone~~ |
        | math | $x^2 + y$ | $4 and 5 dollars |
        | escapes | 1 * 2 * 3, snake_case, \\[x\\] | back\\\\slash |
        | break | one<br>two | `<br>` stays |
        | 中文 | 单元格 **粗体** | 表格 |
        |  | empty cells |  |
        | literal | a \\~\\~not struck\\~\\~ and \\<b\\> | &amp;lt; ok, A & B, 1 < 2 |
        | spaced code | `  a  ` and ` b` | `  ` |
        | destinations | [a](<https://x.com/a b>) [c](<x)y>) | ![i](<img (1).png>) [p](x(y)z) |
        | brackets | see [1] and [TODO], price [USD] 5 | C:\\(x) and 2\\[y] |
        | adjacent | *a*_b_ and **a**__b__ | **_x_** and _**y**_ |
        | backslashes | [d](<a\\\\)>) [g](<a\\\\>) | [f](a\\\\b) [h](a\\b) |
        """,
    ])
    func copyRoundTrips(markdown: String) throws {
        let (_, table) = try tableView(markdown)
        let source = try #require(table.sourceRows)
        let copied = table.markdown()
        let reparsed = MarkdownParser().parse(copied).document.compactMap { block -> [RawTableRow]? in
            if case let .table(_, rows) = block { return rows }
            return nil
        }.first
        // Math is numbered per parse; only what it says has to match.
        func normalized(_ rows: [RawTableRow]?) -> [[[MarkdownInlineNode]]]? {
            rows?.map { $0.cells.map { $0.content.map(Self.withoutMathIdentifiers) } }
        }
        #expect(normalized(reparsed) == normalized(source), "copied:\n\(copied)")
    }

    private static func withoutMathIdentifiers(_ node: MarkdownInlineNode) -> MarkdownInlineNode {
        switch node {
        case let .math(content, _): .math(content: content, replacementIdentifier: "")
        case let .emphasis(children): .emphasis(children: children.map(withoutMathIdentifiers))
        case let .strong(children): .strong(children: children.map(withoutMathIdentifiers))
        case let .strikethrough(children): .strikethrough(children: children.map(withoutMathIdentifiers))
        case let .link(destination, children): .link(destination: destination, children: children.map(withoutMathIdentifiers))
        case let .image(source, children): .image(source: source, children: children.map(withoutMathIdentifiers))
        default: node
        }
    }

    @Test("A <br> tag breaks a cell's line, and <br> written as code stays as written")
    func lineBreakTags() throws {
        let (_, table) = try tableView("""
        | A | B |
        | - | - |
        | one<br>two | `x<br>y` |
        """)
        let cells = table.plainTextRows[1]
        #expect(cells == ["one\ntwo", "x<br>y"])
        #expect(TableExport.csv(rows: table.plainTextRows).contains("\"one\ntwo\",x<br>y"))
    }

    @Test("Copy and Download include rows a long table does not draw")
    func exportIncludesHiddenRows() throws {
        let rows = (1 ... 130).map { "| r\($0) | v\($0) |" }.joined(separator: "\n")
        let (_, table) = try tableView("| A | B |\n| - | - |\n" + rows)
        #expect(table.markdown().hasSuffix("| r130 | v130 |"))
        #expect(TableExport.csv(rows: table.plainTextRows).hasSuffix("r130,v130\r\n"))
    }

    @Test("Download gives CSV with fields quoted only where needed")
    func downloadGivesCSV() throws {
        let (_, table) = try tableView(Self.table)
        let csv = TableExport.csv(rows: table.plainTextRows)
        #expect(csv == "Name,Note,Amount\r\nswift test,a | b,\"1,200\"\r\n\"\"\"quoted\"\"\",\"two\nlines\",3\r\n")
        let data = TableExport.csvData(rows: table.plainTextRows)
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(data: data.dropFirst(3), encoding: .utf8) == csv)
    }

    @Test("A table's plain text leaves out inline code's spacers")
    func plainTextDropsSpacers() throws {
        let (_, table) = try tableView(Self.table)
        let code = try #require(table.contents[safe: 1]?.first)
        #expect(code.string.contains(TextLabel.Attachment.replacementText))
        #expect(TableExport.plainText(code) == "swift test")
    }

    private func titleText(of table: TableView) -> String {
        table.titleLabel.text
    }
}

/// A code block's bar: Copy and Expand at the trailing end; Download is in
/// the sheet Expand opens.
@MainActor
struct CodeBlockBarTests {
    @Test("The bar holds Copy then Expand, left to right")
    func barButtonOrder() throws {
        let view = RenderProbe.view("```swift\nlet a = 1\n```")
        let code = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
        RenderProbe.layout(view)
        #if canImport(UIKit)
            code.layoutIfNeeded()
        #elseif canImport(AppKit)
            code.layoutSubtreeIfNeeded()
        #endif
        let buttons = [code.copyButton, code.expandButton]
        #expect(buttons.allSatisfy { !$0.isHidden && $0.superview === code.barView })
        #expect(code.expandButton.frame.maxX <= code.barView.bounds.width)
        #expect(code.copyButton.frame.maxX <= code.expandButton.frame.minX + 0.5)
        for button in buttons {
            let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: code)
            #expect(code.interactionTarget(at: point) === button)
        }
    }

    @Test("A code block is saved under its language's extension", arguments: [
        ("swift", "code.swift"), ("Python", "code.py"), ("bash", "code.sh"),
        ("typescript", "code.ts"), ("", "code.txt"), ("made-up", "code.txt"),
    ])
    func fileNames(language: String, fileName: String) {
        #expect(CodeFileName.fileName(forLanguage: language) == fileName)
    }

    @Test("The sheet shows the highlighted code under its capitalized language, and saves it under its extension")
    func sheetContent() throws {
        let view = RenderProbe.view("```swift\nlet a = 1\n```\n\n```\nplain\n```")
        let codes = view.contextViews.compactMap { $0 as? CodeView }
        #expect(codes.count == 2)
        let swift = CodeSheetContent(codes[0])
        #expect(swift.title == "Swift")
        #expect(swift.code.string == "let a = 1")
        #expect(swift.code.isEqual(to: codes[0].textView.attributedText))
        #expect(swift.text == "let a = 1")
        #expect(swift.fileName == "code.swift")
        let plain = CodeSheetContent(codes[1])
        #expect(plain.title == CodeSheetText.code)
        #expect(plain.fileName == "code.txt")
    }

    #if canImport(AppKit) && !canImport(UIKit)
        @Test("The sheet fits short code, and wraps code past the reading width")
        func sheetFitsCode() throws {
            let long = String(repeating: "let value = compute(value) + 1; ", count: 12)
            let view = RenderProbe.view("```swift\nlet a = 1\nlet b = 2\n```\n\n```swift\n\(long)\n```")
            let codes = view.contextViews.compactMap { $0 as? CodeView }
            #expect(codes.count == 2)

            let short = CodeSheetContent(codes[0])
            let shortSize = CodeSheetGeometry.size(for: short.code, maxHeight: 800)
            #expect(shortSize.width == CodeSheetGeometry.minSize.width)
            #expect(shortSize.height == CodeSheetGeometry.minSize.height)

            let wide = CodeSheetContent(codes[1])
            #expect(CodeSheetGeometry.textWidth(for: wide.code) == CodeSheetGeometry.maxTextWidth)
            let wideSize = CodeSheetGeometry.size(for: wide.code, maxHeight: 800)
            #expect(wideSize.width < 700)
            let sheet = CodeSheetWindow(content: wide, size: wideSize)
            let layout = try #require(sheet.textView.layoutManager)
            let container = try #require(sheet.textView.textContainer)
            layout.ensureLayout(for: container)
            let used = layout.usedRect(for: container)
            #expect(used.width <= CodeSheetGeometry.maxTextWidth + 2 * CodeSheetGeometry.lineFragmentPadding + 0.5)
            var lines = 0
            layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, _, _, _, _ in
                lines += 1
            }
            #expect(lines > 1)
        }

        @Test("The sheet's bar names the language, or Code when there is none")
        func sheetTitle() throws {
            let view = RenderProbe.view("```swift\nlet a = 1\n```\n\n```\nplain\n```")
            let codes = view.contextViews.compactMap { $0 as? CodeView }
            #expect(codes.count == 2)
            let titles = codes.map { code in
                let content = CodeSheetContent(code)
                let sheet = CodeSheetWindow(content: content, size: CodeSheetGeometry.size(for: content.code, maxHeight: 800))
                #expect(sheet.titleLabel.superview === sheet.contentView)
                #expect(!sheet.titleLabel.frame.isEmpty)
                return sheet.titleLabel.stringValue
            }
            #expect(titles == ["Swift", CodeSheetText.code])
        }

        @Test("A line that sets the sheet's width does not wrap in it")
        func sheetKeepsFittedLine() throws {
            let line = "print(\"a line well under the reading width, but over the minimum\")"
            let view = RenderProbe.view("```swift\n\(line)\n```")
            let code = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            let content = CodeSheetContent(code)
            let size = CodeSheetGeometry.size(for: content.code, maxHeight: 800)
            #expect(size.width > CodeSheetGeometry.minSize.width)
            let sheet = CodeSheetWindow(content: content, size: size)
            let layout = try #require(sheet.textView.layoutManager)
            let container = try #require(sheet.textView.textContainer)
            layout.ensureLayout(for: container)
            var lines = 0
            layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, _, _, _, _ in
                lines += 1
            }
            #expect(lines == 1)
        }
    #endif
}
