@testable import MarkdownView
import SwiftUI
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A streamed answer rebuilds the whole document on every token. The code
/// and table views it shows must come through each rebuild as the same
/// objects, in the same place, never taken down and put up again: swapping
/// them makes a host flicker, drop a selection or scroll position, and
/// re-run their layout on every token.
@MainActor
struct MarkdownStreamingViewReuseTests {
    private static let document = """
    Intro paragraph before anything else.

    ```swift
    let first = 1
    print(first)
    ```

    | Name | Value |
    | :-- | --: |
    | alpha | 1 |
    | beta | 2 |

    A paragraph between the blocks, with `inline code`.

    ```python
    second = 2
    ```

    | A | B | C |
    | - | - | - |
    | x | y | z |

    Closing words.
    """

    /// The document cut after every `step` characters, ending with the
    /// whole of it.
    private static func prefixes(step: Int) -> [String] {
        let characters = Array(document)
        var result = stride(from: step, to: characters.count, by: step).map { String(characters[0 ..< $0]) }
        result.append(document)
        return result
    }

    private struct Seen {
        var order: [ObjectIdentifier] = []
        var everSeen: Set<ObjectIdentifier> = []
    }

    @Test("Streaming keeps every code and table view once it appears", arguments: [1, 3, 7])
    func streamingKeepsContextViews(step: Int) throws {
        let view = MarkdownTextView()
        var previous: [PlatformView] = []
        var created: Set<ObjectIdentifier> = []

        for (index, prefix) in Self.prefixes(step: step).enumerated() {
            RenderProbe.show(prefix, in: view)
            let current = view.contextViews
            created.formUnion(current.map(ObjectIdentifier.init))

            // Each view shown before is shown again, in the same place.
            #expect(
                current.count >= previous.count,
                "step \(index) dropped a context view: \(previous.count) → \(current.count)"
            )
            for (position, old) in previous.enumerated() where position < current.count {
                #expect(
                    current[position] === old,
                    "step \(index) replaced the view at \(position) (\(type(of: old)))"
                )
            }
            // Every view shown sits in this view, and nothing else of its
            // kind does.
            for shown in current {
                #expect(shown.superview === view, "step \(index) left a \(type(of: shown)) detached")
            }
            let attached = view.subviews.filter { $0 is CodeView || $0 is TableView }
            #expect(attached.count == current.count, "step \(index) left a stale context view attached")
            previous = current
        }

        // No view was made, thrown away and made again along the way.
        #expect(created.count == previous.count)
        #expect(previous.compactMap { $0 as? CodeView }.count == 2)
        #expect(previous.compactMap { $0 as? TableView }.count == 2)
    }

    @Test("Streaming keeps each table's cells, adding only the new ones")
    func streamingKeepsTableCells() throws {
        let view = MarkdownTextView()
        var cellsByTable: [ObjectIdentifier: [ObjectIdentifier]] = [:]

        for prefix in Self.prefixes(step: 2) {
            RenderProbe.show(prefix, in: view)
            for table in view.contextViews.compactMap({ $0 as? TableView }) {
                let cells = table.cellViews.map(ObjectIdentifier.init)
                let key = ObjectIdentifier(table)
                if let before = cellsByTable[key] {
                    let kept = Array(cells.prefix(before.count))
                    // A row grows by a cell at a time, so earlier cells stay;
                    // a column count change may rebuild, but never shrinks.
                    if before.count <= cells.count, kept != before {
                        Issue.record("a table swapped cells it already had while streaming")
                    }
                }
                cellsByTable[key] = cells
            }
        }
        #expect(cellsByTable.count == 2)
    }

    @Test("Streaming a code block keeps its view and ends with its full source")
    func streamingKeepsCodeViewContent() throws {
        let view = MarkdownTextView()
        var codeView: CodeView?
        for prefix in Self.prefixes(step: 1) {
            RenderProbe.show(prefix, in: view)
            guard let first = view.contextViews.compactMap({ $0 as? CodeView }).first else { continue }
            if let codeView {
                #expect(first === codeView)
            }
            codeView = first
        }
        #expect(codeView?.content == "let first = 1\nprint(first)")
    }

    @Test("A theme change mid-stream keeps the views")
    func themeChangeKeepsViews() throws {
        let view = MarkdownTextView()
        RenderProbe.show(Self.document, in: view)
        let before = view.contextViews

        var theme = MarkdownTheme.default
        theme.colors.body = .systemRed
        view.theme = theme
        RenderProbe.show(Self.document, in: view, theme: theme)

        #expect(view.contextViews.count == before.count)
        #expect(zip(view.contextViews, before).allSatisfy { $0 === $1 })
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        @Test("Streaming through SwiftUI keeps every code and table view once it appears")
        func swiftUIStreamingKeepsContextViews() throws {
            let window = NSWindow(
                contentRect: .init(x: 0, y: 0, width: 480, height: 1200),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: true
            )
            let prefixes = Self.prefixes(step: 5)
            let host = NSHostingView(rootView: MarkdownView(RenderProbe.content(prefixes[0])))
            window.contentView = host
            host.layoutSubtreeIfNeeded()

            var previous: [PlatformView] = []
            var created: Set<ObjectIdentifier> = []
            var markdownView: MarkdownTextView?
            for (index, prefix) in prefixes.enumerated() {
                host.rootView = MarkdownView(RenderProbe.content(prefix))
                host.layoutSubtreeIfNeeded()
                let view = try #require(firstMarkdownTextView(in: host))
                if let markdownView {
                    #expect(view === markdownView, "step \(index) replaced the markdown view itself")
                }
                markdownView = view
                let current = view.contextViews
                created.formUnion(current.map(ObjectIdentifier.init))
                #expect(current.count >= previous.count, "step \(index) dropped a context view")
                for (position, old) in previous.enumerated() where position < current.count {
                    #expect(current[position] === old, "step \(index) replaced the view at \(position)")
                }
                let problems = MarkdownStreamingVisibilityTests.problems(in: view)
                #expect(problems.isEmpty, "step \(index): \(problems)")
                previous = current
            }
            #expect(created.count == previous.count)
            #expect(previous.count == 4)
        }

        private func firstMarkdownTextView(in view: NSView) -> MarkdownTextView? {
            var queue: [NSView] = [view]
            while !queue.isEmpty {
                let view = queue.removeFirst()
                if let match = view as? MarkdownTextView {
                    return match
                }
                queue.append(contentsOf: view.subviews)
            }
            return nil
        }
    #endif
}
