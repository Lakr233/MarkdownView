@testable import Litext
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit

    /// The UIKit half of the table's shared cell selection: a selection
    /// running across cells, what it copies, and its edit menu.
    @MainActor
    struct TableSelectionUIKitTests {
        private static let document = """
        Before the table.

        | Name | Status | Note |
        | :- | :-: | -: |
        | Alpha | ok | first |
        | Beta | a\\|b | second |
        | Gamma | done | third |

        After the table.
        """

        private func render(_ markdown: String) -> (UIWindow, MarkdownTextView) {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
            let controller = UIViewController()
            window.rootViewController = controller
            window.isHidden = false
            let view = MarkdownTextView()
            view.frame = CGRect(x: 16, y: 60, width: 358, height: 400)
            controller.view.backgroundColor = .systemBackground
            controller.view.addSubview(view)
            view.setMarkdown(markdown)
            view.frame.size.height = view.boundingSize(for: 358).height
            view.layoutIfNeeded()
            return (window, view)
        }

        private func select(in table: TableView, from start: (Int, Int), to end: (Int, Int)) {
            let group = table.selectionGroup
            group.setSelection(
                group.normalizedSelection(
                    from: .init(member: start.0, offset: start.1),
                    to: .init(member: end.0, offset: end.1),
                ),
                presentsMenu: false,
            )
        }

        @Test
        func `A selection runs across cells and copies them as a grid`() throws {
            let (window, view) = render(Self.document)
            defer { window.isHidden = true }
            let table = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
            #expect(table.selectionGroup.labels.elementsEqual(table.cellViews, by: ===))

            select(in: table, from: (3, 2), to: (6, 2))
            #expect(table.selectionGroup.selectedPlainText() == "pha\tok\tfirst\nBe")
            #expect(table.cellViews[4].selectionRange == NSRange(location: 0, length: 2))
        }

        @Test
        func `The edit menu adds Copy as Markdown after the system's commands`() throws {
            guard #available(iOS 16.0, macCatalyst 16.0, *) else { return }
            let (window, view) = render(Self.document)
            defer { window.isHidden = true }
            let table = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
            select(in: table, from: (4, 0), to: (7, 3))

            let copy = UIAction(title: "Copy") { _ in }
            let menu = try #require(table.textSelectionGroup(
                table.selectionGroup,
                editMenuForSuggestedActions: [copy],
            ))
            #expect(menu.children.first === copy)
            let markdownAction = try #require(menu.children.last as? UIAction)
            #expect(markdownAction.image != nil)

            UIPasteboard.general.string = ""
            markdownAction.performWithSender(nil, target: nil)
            #expect(UIPasteboard.general.string == """
            | Name | Status | Note |
            | :--- | :---: | ---: |
            |  | ok | first |
            | Beta | a\\|b |  |
            """)
        }
    }
#endif
