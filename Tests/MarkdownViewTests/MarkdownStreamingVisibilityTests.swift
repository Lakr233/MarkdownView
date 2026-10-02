import Foundation
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A streamed answer must end with every code block and table on screen.
///
/// Keeping the same view objects is not enough: a view can be the right one,
/// attached to the right parent, and still be hidden or left where an old
/// layout put it, which shows up as a blank gap the size of the block.
@MainActor
struct MarkdownStreamingVisibilityTests {
    private static func exampleDocument() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "ExampleDocument", withExtension: "md"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func prefixes(of document: String, step: Int) -> [String] {
        let characters = Array(document)
        var result = stride(from: step, to: characters.count, by: step).map { String(characters[0 ..< $0]) }
        result.append(document)
        return result
    }

    /// What is wrong with the views `view` shows, one line per problem.
    static func problems(in view: MarkdownTextView) -> [String] {
        var problems: [String] = []
        let runs = view.textLabelView.layoutRuns(matching: .contextView)
        let placed = Set(runs.compactMap { ($0.attributes[.contextView] as? PlatformView).map(ObjectIdentifier.init) })
        for (index, shown) in view.contextViews.enumerated() {
            let name = "\(type(of: shown)) #\(index)"
            if shown.superview !== view {
                problems.append("\(name) is detached")
            }
            if shown.isHidden {
                problems.append("\(name) is hidden")
            }
            if !placed.contains(ObjectIdentifier(shown)) {
                problems.append("\(name) has no line in the layout")
            }
            if shown.frame.height <= 0 || shown.frame.width <= 0 {
                problems.append("\(name) has no size: \(shown.frame)")
            }
            if shown.frame.maxY > view.bounds.maxY + 0.5 {
                problems.append("\(name) sits past the bottom: \(shown.frame) in \(view.bounds)")
            }
        }
        // Each view stands on its own line, at the size the line reserved.
        let label = view.textLabelView
        for run in runs {
            guard let shown = run.attributes[.contextView] as? PlatformView else { continue }
            let expectedY = label.frame.minY + label.bounds.height - run.lineRect.maxY
            if abs(shown.frame.minY - expectedY) > 0.5 {
                problems.append("\(type(of: shown)) is at y \(shown.frame.minY), its line at \(expectedY)")
            }
            if !view.contextViews.contains(where: { $0 === shown }) {
                problems.append("the text places a \(type(of: shown)) the view does not track")
            }
        }
        let boxes = view.verticalLayoutBoxes()
        for (upper, lower) in zip(boxes, boxes.dropFirst()) where upper.frame.maxY > lower.frame.minY + 1 {
            problems.append("\(upper.label) \(upper.frame) overlaps \(lower.label) \(lower.frame)")
        }
        let attached = view.subviews.filter { $0 is CodeView || $0 is TableView }
        for stray in attached where !view.contextViews.contains(where: { $0 === stray }) && !stray.isHidden {
            problems.append("a stale \(type(of: stray)) is still showing")
        }
        return problems
    }

    @Test(arguments: [3, 8])
    func `Streaming the example document ends with every block on screen`(step: Int) throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        for prefix in Self.prefixes(of: document, step: step) {
            RenderProbe.show(prefix, in: view)
            let problems = Self.problems(in: view)
            #expect(problems.isEmpty, "after \(prefix.count) characters: \(problems)")
            if !problems.isEmpty {
                return
            }
        }
        #expect(view.contextViews.compactMap { $0 as? TableView }.count == 3)
        #expect(view.contextViews.compactMap { $0 as? CodeView }.count == 3)
    }

    @Test(arguments: [5])
    func `Streaming again into the same view ends with every block on screen`(step: Int) throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        for round in 0 ..< 2 {
            RenderProbe.show("", in: view)
            for prefix in Self.prefixes(of: document, step: step + round) {
                RenderProbe.show(prefix, in: view)
                let problems = Self.problems(in: view)
                #expect(problems.isEmpty, "round \(round), after \(prefix.count) characters: \(problems)")
                if !problems.isEmpty {
                    return
                }
            }
        }
    }

    /// A host resizes the view a pass after its content changes, so every
    /// update is first laid out in the old frame.
    @Test(arguments: [7])
    func `Content laid out in a stale frame shows every block once resized`(step: Int) throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 700, height: 10)
        for prefix in Self.prefixes(of: document, step: step) {
            view.setContentImmediately(RenderProbe.content(prefix))
            RenderProbe.layout(view)
            view.frame.size.height = view.boundingSize(for: view.bounds.width).height
            RenderProbe.layout(view)
            let problems = Self.problems(in: view)
            #expect(problems.isEmpty, "after \(prefix.count) characters: \(problems)")
            if !problems.isEmpty {
                return
            }
        }
    }

    @Test
    func `Rotating after a stream keeps every block on screen`() throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        for prefix in Self.prefixes(of: document, step: 9) {
            RenderProbe.show(prefix, in: view, width: 744)
        }
        for width: CGFloat in [1133, 744, 320, 1366, 500, 744] {
            view.frame.size.width = width
            RenderProbe.layout(view)
            view.frame.size.height = view.boundingSize(for: width).height
            RenderProbe.layout(view)
            let problems = Self.problems(in: view)
            #expect(problems.isEmpty, "at width \(width): \(problems)")
        }
    }

    // MARK: - Paths a host takes

    /// What a host does: hands content over through the throttle and lets the
    /// run loop deliver it, then sizes the view to what it reports.
    @Test
    func `Streaming through the throttle ends with every block on screen`() async throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 640, height: 10)
        for prefix in Self.prefixes(of: document, step: 6) {
            view.setContent(RenderProbe.content(prefix))
            try await Task.sleep(nanoseconds: 1_000_000)
            view.frame.size.height = view.boundingSize(for: 640).height
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        view.frame.size.height = view.boundingSize(for: 640).height
        RenderProbe.layout(view)
        #expect(view.textLabelView.attributedText.string.contains("Thank you for using"))
        #expect(Self.problems(in: view).isEmpty, "\(Self.problems(in: view))")
        #expect(view.contextViews.count == 6)
    }

    @Test
    func `Highlighting that finishes after a stream keeps every block on screen`() async throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        for prefix in Self.prefixes(of: document, step: 11) {
            RenderProbe.show(prefix, in: view)
        }
        let before = view.contextViews
        // Let highlight results arrive and their notifications land.
        for _ in 0 ..< 20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            RenderProbe.layout(view)
        }
        #expect(Self.problems(in: view).isEmpty, "\(Self.problems(in: view))")
        #expect(view.contextViews.count == before.count)
        #expect(zip(view.contextViews, before).allSatisfy { $0 === $1 })
    }

    @Test
    func `A theme change after a stream keeps every block on screen`() throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        for prefix in Self.prefixes(of: document, step: 13) {
            RenderProbe.show(prefix, in: view)
        }
        var theme = MarkdownTheme.default
        theme.colors.body = .systemRed
        view.theme = theme
        RenderProbe.show(document, in: view, theme: theme)
        #expect(Self.problems(in: view).isEmpty, "\(Self.problems(in: view))")
        #expect(view.contextViews.count == 6)
    }

    // MARK: - Documents that change shape

    private static let mixed = """
    Start.

    ```swift
    let a = 1
    ```

    | A | B |
    | - | - |
    | 1 | 2 |

    Middle.

    ```python
    b = 2
    ```

    | C | D |
    | - | - |
    | 3 | 4 |

    End.
    """

    @Test
    func `Removing blocks detaches them and keeps the rest on screen`() {
        let view = MarkdownTextView()
        RenderProbe.show(Self.mixed, in: view)
        let tables = view.contextViews.compactMap { $0 as? TableView }
        #expect(tables.count == 2)

        let withoutFirstTable = Self.mixed.replacingOccurrences(of: "| A | B |\n| - | - |\n| 1 | 2 |\n", with: "")
        RenderProbe.show(withoutFirstTable, in: view)
        #expect(Self.problems(in: view).isEmpty, "\(Self.problems(in: view))")
        #expect(view.contextViews.count == 3)
        let shownViews = view.subviews.filter { ($0 is CodeView || $0 is TableView) && !$0.isHidden }
        #expect(shownViews.count == 3)

        // And back again.
        RenderProbe.show(Self.mixed, in: view)
        #expect(Self.problems(in: view).isEmpty, "\(Self.problems(in: view))")
        #expect(view.contextViews.count == 4)
    }

    @Test
    func `Swapping the order of blocks keeps every block on screen`() {
        let view = MarkdownTextView()
        RenderProbe.show(Self.mixed, in: view)
        let parts = Self.mixed.components(separatedBy: "Middle.")
        let swapped = parts[1] + "\n\nMiddle.\n\n" + parts[0]
        for document in [swapped, Self.mixed, swapped, "Nothing here.", Self.mixed] {
            RenderProbe.show(document, in: view)
            #expect(Self.problems(in: view).isEmpty, "\(Self.problems(in: view))")
        }
        #expect(view.contextViews.count == 4)
    }

    @Test
    func `Clearing mid-block and streaming again keeps every block on screen`() throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        let prefixes = Self.prefixes(of: document, step: 17)
        // Cut the stream at a few points, including inside a fence and a table.
        for cut in [prefixes.count / 5, prefixes.count / 2, prefixes.count * 4 / 5] {
            RenderProbe.show("", in: view)
            for prefix in prefixes.prefix(cut) {
                RenderProbe.show(prefix, in: view)
            }
            #expect(Self.problems(in: view).isEmpty, "cut at \(cut): \(Self.problems(in: view))")
        }
        for prefix in prefixes {
            RenderProbe.show(prefix, in: view)
        }
        #expect(Self.problems(in: view).isEmpty, "\(Self.problems(in: view))")
        #expect(view.contextViews.count == 6)
    }

    @Test
    func `Two views sharing one provider never take each other's blocks`() throws {
        let provider = ReusableViewProvider()
        let first = MarkdownTextView(viewProvider: provider)
        let second = MarkdownTextView(viewProvider: provider)
        let document = try Self.exampleDocument()
        let prefixes = Self.prefixes(of: document, step: 23)
        for (index, prefix) in prefixes.enumerated() {
            RenderProbe.show(prefix, in: first)
            RenderProbe.show(prefixes[max(0, index - 3)], in: second)
            for view in [first, second] {
                #expect(Self.problems(in: view).isEmpty, "step \(index): \(Self.problems(in: view))")
            }
            let firstIDs = Set(first.contextViews.map(ObjectIdentifier.init))
            let secondIDs = Set(second.contextViews.map(ObjectIdentifier.init))
            #expect(firstIDs.isDisjoint(with: secondIDs), "step \(index) shows one block view in both")
        }
        // The first view is done; the second keeps changing and must not
        // disturb it.
        RenderProbe.show(Self.mixed, in: second)
        RenderProbe.show("", in: second)
        RenderProbe.layout(first)
        #expect(Self.problems(in: first).isEmpty, "\(Self.problems(in: first))")
        #expect(first.contextViews.count == 6)
    }

    @Test
    func `A table that crosses the truncation threshold while streaming stays on screen`() {
        var rows = ["| N | Name |", "| - | - |"]
        for index in 0 ..< 130 {
            rows.append("| \(index) | row \(index) |")
        }
        let document = "Before.\n\n" + rows.joined(separator: "\n") + "\n\nAfter.\n\n```swift\nlet x = 1\n```\n"
        let view = MarkdownTextView()
        var table: TableView?
        for prefix in Self.prefixes(of: document, step: 29) {
            RenderProbe.show(prefix, in: view)
            let problems = Self.problems(in: view)
            #expect(problems.isEmpty, "after \(prefix.count) characters: \(problems)")
            if !problems.isEmpty {
                return
            }
            if let shown = view.contextViews.compactMap({ $0 as? TableView }).first {
                if let table {
                    #expect(shown === table)
                }
                table = shown
            }
        }
        #expect(view.contextViews.count == 2)
    }
}
