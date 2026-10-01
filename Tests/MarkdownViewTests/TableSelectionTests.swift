@testable import Litext
@testable import MarkdownView
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    /// A table's cells share one selection: a drag runs from one cell into
    /// the next, and what it copies keeps the table's rows and columns.
    struct TableSelectionTests {
        private static let table = """
        before

        | Name | Status | Note |
        | :- | :-: | -: |
        | Alpha | ok | first |
        | Beta | a\\|b | second |
        | Gamma | done | third |

        after
        """

        @MainActor
        private func tableView(in view: MarkdownTextView) throws -> TableView {
            try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        }

        /// Selects from `start` in one cell to `end` in another, as a drag
        /// between them does. Cells are counted row by row, header first.
        @MainActor
        private func select(
            in table: TableView,
            from start: (cell: Int, offset: Int),
            to end: (cell: Int, offset: Int)
        ) {
            let group = table.selectionGroup
            group.setSelection(
                group.normalizedSelection(
                    from: .init(member: start.cell, offset: start.offset),
                    to: .init(member: end.cell, offset: end.offset)
                ),
                presentsMenu: false
            )
        }

        @MainActor
        @Test("Every cell joins the table's selection group, row by row")
        func cellsJoinOneGroup() throws {
            let table = try tableView(in: RenderProbe.view(Self.table))
            let cells = table.cellViews
            #expect(cells.count == 12)
            #expect(table.selectionGroup.labels.elementsEqual(cells, by: ===))
            #expect(cells.allSatisfy { $0.selectionGroup === table.selectionGroup && $0.isSelectable })
        }

        @MainActor
        @Test("A selection across cells copies tabs between cells and line breaks between rows")
        func selectionAcrossCellsCopiesAsGrid() throws {
            let table = try tableView(in: RenderProbe.view(Self.table))
            // From "pha" in Alpha to "Be" in Beta.
            select(in: table, from: (3, 2), to: (6, 2))
            #expect(table.selectionGroup.selectedPlainText() == "pha\tok\tfirst\nBe")

            table.selectionGroup.selectAll()
            #expect(table.selectionGroup.selectedPlainText() == """
            Name\tStatus\tNote
            Alpha\tok\tfirst
            Beta\ta|b\tsecond
            Gamma\tdone\tthird
            """)
        }

        @MainActor
        @Test("Selecting in the table clears the document's selection, and the other way round")
        func tableAndDocumentSelectionsExclude() throws {
            let view = RenderProbe.view(Self.table)
            let table = try tableView(in: view)
            let text = view.textLabelView.attributedText.string as NSString

            view.textLabelView.selectionRange = text.range(of: "before")
            table.selectionGroup.selectAll()
            #expect(view.textLabelView.selectionRange == nil)

            view.textLabelView.selectAll()
            #expect(!table.selectionGroup.hasSelection)
        }

        @MainActor
        @Test("Streaming into one cell keeps a selection in the others")
        func streamingKeepsSelectionInOtherCells() throws {
            let view = RenderProbe.view(Self.table)
            let table = try tableView(in: view)
            let cells = table.cellViews
            select(in: table, from: (3, 0), to: (4, 2))
            #expect(table.selectionGroup.selectedPlainText() == "Alpha\tok")

            RenderProbe.show(Self.table.replacingOccurrences(of: "third", with: "third and more"), in: view)

            #expect(table.cellViews.elementsEqual(cells, by: ===))
            #expect(table.selectionGroup.selectedPlainText() == "Alpha\tok")
        }

        @MainActor
        @Test("A new row joins the group in reading order")
        func newRowJoinsGroup() throws {
            let view = RenderProbe.view(Self.table)
            let table = try tableView(in: view)
            RenderProbe.show(
                Self.table.replacingOccurrences(of: "| Gamma | done | third |", with: """
                | Gamma | done | third |
                | Delta | new | fourth |
                """),
                in: view
            )
            #expect(table.cellViews.count == 15)
            #expect(table.selectionGroup.labels.elementsEqual(table.cellViews, by: ===))
            table.selectionGroup.selectAll()
            #expect(table.selectionGroup.selectedPlainText()?.hasSuffix("third\nDelta\tnew\tfourth") == true)
        }

        @MainActor
        @Test("Copy as Markdown gives the selected cells as a table, header included")
        func selectionAsMarkdown() throws {
            let table = try tableView(in: RenderProbe.view(Self.table))
            // From Alpha's "ok" to Beta's "a|b".
            select(in: table, from: (4, 0), to: (7, 3))
            #expect(table.selectedMarkdown() == """
            | Name | Status | Note |
            | :--- | :---: | ---: |
            |  | ok | first |
            | Beta | a\\|b |  |
            """)

            select(in: table, from: (0, 0), to: (1, 6))
            #expect(table.selectedMarkdown() == """
            | Name | Status |
            | :--- | :---: |
            """)
        }

        @MainActor
        @Test("A truncated table selects only the rows it draws")
        func truncatedTableSelectsVisibleRows() throws {
            let rows = (1 ... 20).map { "| r\($0) | v\($0) |" }.joined(separator: "\n")
            let table = try tableView(in: RenderProbe.view("| A | B |\n| - | - |\n" + rows))
            #expect(table.cellViews.count == 18)
            table.selectionGroup.selectAll()
            let copied = try #require(table.selectionGroup.selectedPlainText())
            #expect(copied.hasPrefix("A\tB\nr1\tv1"))
            #expect(copied.hasSuffix("r8\tv8"))
        }
    }
#endif
