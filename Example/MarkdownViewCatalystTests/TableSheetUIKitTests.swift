@testable import MarkdownView
import MarkdownParser
import Testing
import UIKit

/// The full table's sheet on UIKit: a collection view with the header
/// pinned, the outer columns' text on the sheet's margins, and a header tap
/// that sorts the rows in place.
@MainActor
struct TableSheetUIKitTests {
    private static let markdown = """
    | Name | Count | Note |
    | :-- | --: | :-: |
    | beta | 10 | second |
    | alpha | 2 | first |
    | gamma | | none |
    | delta | 7 | a much longer note that wraps onto a second line in its column |
    """

    private func makeSheet(size: CGSize = CGSize(width: 600, height: 500)) throws -> (UIWindow, TableSheetViewController) {
        let view = MarkdownTextView()
        view.setContentImmediately(.init(parserResult: MarkdownParser().parse(Self.markdown), theme: .default))
        view.frame = .init(x: 0, y: 0, width: 480, height: view.boundingSize(for: 480).height)
        view.layoutIfNeeded()
        let table = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        let sheet = TableSheetViewController(content: TableSheetContent(table))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = UINavigationController(rootViewController: sheet)
        window.isHidden = false
        window.layoutIfNeeded()
        sheet.collectionView.layoutIfNeeded()
        return (window, sheet)
    }

    private func cell(_ sheet: TableSheetViewController, row: Int, column: Int) -> TableSheetCell? {
        sheet.collectionView.cellForItem(at: IndexPath(item: column, section: row)) as? TableSheetCell
    }

    @Test("Every row and column is laid out, filling the width")
    func cellsFillTheSheet() throws {
        let (window, sheet) = try makeSheet()
        let collection = sheet.collectionView
        #expect(collection.numberOfSections == 5)
        #expect(collection.numberOfItems(inSection: 0) == 3)
        let width = collection.bounds.width - collection.adjustedContentInset.left - collection.adjustedContentInset.right
        #expect(abs(collection.collectionViewLayout.collectionViewContentSize.width - width) < 0.5)
        let first = try #require(cell(sheet, row: 1, column: 0))
        // The first column's text sits on the sheet's margin, not at the edge.
        #expect(first.label.frame.minX >= sheet.systemMinimumLayoutMargins.leading - 0.5)
        #expect(first.frame.minX == 0)
        withExtendedLifetime(window) {}
    }

    @Test("The header stays at the top while the rows scroll under it")
    func headerIsPinned() throws {
        let (window, sheet) = try makeSheet(size: CGSize(width: 600, height: 220))
        let collection = sheet.collectionView
        collection.contentOffset.y = 60 - collection.adjustedContentInset.top
        collection.layoutIfNeeded()
        let header = try #require(cell(sheet, row: 0, column: 0))
        #expect(abs(header.frame.minY - 60) < 0.5)
        #expect(header.layer.zPosition >= 0)
        withExtendedLifetime(window) {}
    }

    @Test("Tapping a header sorts the rows by it, and again reverses them")
    func headerTapSorts() throws {
        let (window, sheet) = try makeSheet()
        let header = IndexPath(item: 1, section: 0)
        sheet.collectionView(sheet.collectionView, didSelectItemAt: header)
        #expect(sheet.sort == TableSort(column: 1, direction: .ascending))
        #expect(sheet.order == [1, 3, 0, 2])
        sheet.collectionView(sheet.collectionView, didSelectItemAt: header)
        #expect(sheet.order == [0, 3, 1, 2])
        sheet.collectionView(sheet.collectionView, didSelectItemAt: header)
        #expect(sheet.sort == nil)
        #expect(sheet.order == [0, 1, 2, 3])
        #expect(!sheet.collectionView(sheet.collectionView, shouldSelectItemAt: IndexPath(item: 0, section: 1)))
        withExtendedLifetime(window) {}
    }

    @Test("The sheet renders in light and dark appearance")
    func snapshots() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let (window, sheet) = try makeSheet()
            window.overrideUserInterfaceStyle = style
            sheet.collectionView(sheet.collectionView, didSelectItemAt: IndexPath(item: 1, section: 0))
            window.layoutIfNeeded()
            sheet.collectionView.layoutIfNeeded()
            // The window is never on screen, so render its layers directly.
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
                window.layer.render(in: context.cgContext)
            }
            let name = style == .dark ? "dark" : "light"
            // Set TABLE_SHEET_SNAPSHOTS to keep the images, in the runner's
            // temporary directory, for a look at the sheet.
            if ProcessInfo.processInfo.environment["TABLE_SHEET_SNAPSHOTS"] != nil, let data = image.pngData() {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("table-sheet-\(name).png")
                try data.write(to: url)
                print("table sheet snapshot: \(url.path)")
            }
            #expect(image.size == window.bounds.size)
        }
    }
}
