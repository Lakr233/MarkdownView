import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The code, table and grid views share one body across UIKit and AppKit.
/// These read back what a reader gets from each — text, links, alignment,
/// copy text, drawn rows — so a platform split that drifts shows up here.
/// The Mac Catalyst test target carries the same file for the UIKit half.
@MainActor
struct SharedPlatformViewTests {
    private static let codeSource = "let tab =\t\"x\"\nprint(\"日本語 🎉\")"

    private static let document = """
    Intro paragraph.

    ```swift
    \(codeSource)
    ```

    | Left | Center | Right |
    | :-- | :-: | --: |
    | a<br>b | [link](https://example.com/c) | c |
    | 1 | 2 | 3 |
    | 4 | 5 | 6 |

    Outro paragraph.
    """

    @Test("Code blocks keep their source byte for byte")
    func codeBlocksKeepTheirSource() throws {
        let view = render(Self.document)
        let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)

        #expect(codeView.content == Self.codeSource)
        #expect(codeView.textView.attributedText.string == Self.codeSource)
        #expect(codeView.attributedStringRepresentation().string == Self.codeSource)
        #expect(languageLabelText(of: codeView) == "swift")
        #expect(codeView.lineNumberView.lineCount == 2)

        view.textLabelView.selectAll()
        let copied = try #require(view.textLabelView.selectedPlainText())
        #expect(copied.contains(Self.codeSource))
    }

    @Test("Tables keep cell text, links and column alignment")
    func tablesKeepCellTextLinksAndAlignment() throws {
        let view = render(Self.document)
        let tableView = try #require(view.contextViews.compactMap { $0 as? TableView }.first)

        #expect(tableView.columnAlignments == [.left, .center, .right])
        #expect(tableView.cellViews.map(\.attributedText.string) == [
            "Left", "Center", "Right",
            "a\nb", "link", "c",
            "1", "2", "3",
            "4", "5", "6",
        ])
        let expectedAlignments: [NSTextAlignment] = [.left, .center, .right]
        for (index, cell) in tableView.cellViews.enumerated() {
            let style = cell.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            #expect(style?.alignment == expectedAlignments[index % 3], "cell \(index)")
        }

        let linkCell = tableView.cellViews[4]
        let link = linkCell.attributedText.attribute(.link, at: 0, effectiveRange: nil)
        #expect(String(describing: link ?? "nil") == "https://example.com/c")

        #expect(tableView.attributedStringRepresentation().string == [
            "Left\tCenter\tRight\t",
            "a\nb\tlink\tc\t",
            "1\t2\t3\t",
            "4\t5\t6\t",
        ].joined(separator: "\n"))
    }

    @Test("The grid draws the header and every other data row")
    func gridDrawsHeaderAndStripes() throws {
        let view = render(Self.document)
        let tableView = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        let gridView = try #require(findGridView(in: tableView))
        let hostLayer: CALayer? = gridView.layer
        let shapes = (hostLayer?.sublayers ?? []).compactMap { $0 as? CAShapeLayer }
        // Background, stripes, title bar and header, the border and row
        // lines, then the column lines.
        #expect(shapes.count == 5)
        guard shapes.count == 5 else { return }

        let cells = tableView.cellViews
        let headerRow = try #require(shapes[2].path).boundingBoxOfPath
        let stripeRows = try #require(shapes[1].path).boundingBoxOfPath
        #expect(shapes[1].mask != nil)
        #expect(shapes[4].mask != nil)

        // The header band ends where the first data row's cells begin.
        let firstDataCell = cells[3].convert(cells[3].bounds, to: gridView)
        #expect(headerRow.minY < cells[0].convert(cells[0].bounds, to: gridView).minY)
        #expect(headerRow.maxY <= firstDataCell.minY)
        // Only the second of the three data rows is striped.
        let secondDataCell = cells[6].convert(cells[6].bounds, to: gridView)
        let thirdDataCell = cells[9].convert(cells[9].bounds, to: gridView)
        #expect(stripeRows.minY > firstDataCell.maxY)
        #expect(stripeRows.minY <= secondDataCell.minY)
        #expect(stripeRows.maxY >= secondDataCell.maxY)
        #expect(stripeRows.maxY <= thirdDataCell.minY)
    }

    @Test("A rebuild wires new context views and drops the ones it stopped showing")
    func rebuildWiresContextViews() throws {
        let view = render(Self.document)
        let tableView = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        #expect(tableView.superview === view)
        #expect(tableView.textSelectionDelegate === view)

        show("```swift\n\(Self.codeSource)\n```", in: view)
        #expect(tableView.superview == nil)
        let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
        #expect(codeView.superview === view)
        #expect(codeView.textView.delegate === view)
        #expect(codeView.content == Self.codeSource)
    }

    @Test("Context views sit in document order across the full width")
    func contextViewsSitInDocumentOrder() throws {
        let view = render(Self.document)
        #expect(view.contextViews.count == 2)
        let frames = view.contextViews.map(\.frame)
        for frame in frames {
            #expect(frame.minX == view.textLabelView.frame.minX)
            #expect(frame.width == view.textLabelView.bounds.width)
            #expect(frame.height > 0)
            #expect(frame.maxY <= view.bounds.height)
        }
        #expect(frames[0].maxY <= frames[1].minY)
        #expect(view.contextViews.allSatisfy { !$0.isHidden })
    }

    // MARK: - Helpers

    private func render(_ markdown: String, width: CGFloat = 480) -> MarkdownTextView {
        let view = MarkdownTextView()
        show(markdown, in: view, width: width)
        return view
    }

    private func show(_ markdown: String, in view: MarkdownTextView, width: CGFloat = 480) {
        view.setContentImmediately(.init(
            parserResult: MarkdownParser().parse(markdown),
            theme: .default
        ))
        view.frame = .init(x: 0, y: 0, width: width, height: view.boundingSize(for: width).height)
        #if canImport(UIKit)
            view.setNeedsLayout()
            view.layoutIfNeeded()
        #elseif canImport(AppKit)
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
        #endif
    }

    private func languageLabelText(of codeView: CodeView) -> String? {
        #if canImport(UIKit)
            codeView.languageLabel.text
        #elseif canImport(AppKit)
            codeView.languageLabel.stringValue
        #endif
    }

    private func findGridView(in view: PlatformView) -> GridView? {
        if let grid = view as? GridView { return grid }
        for subview in view.subviews {
            if let grid = findGridView(in: subview) { return grid }
        }
        return nil
    }
}
