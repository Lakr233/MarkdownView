import Litext
import LitextAnimation
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit

    private typealias HostWindow = UIWindow
#elseif canImport(AppKit)
    import AppKit

    private typealias HostWindow = NSWindow
#endif

#if !targetEnvironment(macCatalyst)
    @MainActor
    struct MarkdownStreamViewTests {
        private static let paragraphs = (0 ..< 6).map { "Paragraph \($0) of an answer that streams in." }

        private func content(_ markdown: String) -> MarkdownContent {
            MarkdownContent(markdown: markdown, theme: .default)
        }

        /// A stream view in a window, showing the first paragraph.
        private func makeHostedView(identity: AnyHashable? = nil) -> (MarkdownStreamView, HostWindow) {
            let frame = CGRect(x: 0, y: 0, width: 400, height: 600)
            let view = MarkdownStreamView()
            view.frame = frame
            #if canImport(UIKit)
                let window = UIWindow(frame: frame)
                window.addSubview(view)
            #elseif canImport(AppKit)
                let window = NSWindow(
                    contentRect: frame,
                    styleMask: [.titled, .resizable],
                    backing: .buffered,
                    defer: true,
                )
                window.contentView = view
            #endif
            view.streamIdentity = identity
            view.setContentImmediately(content(Self.paragraphs[0]))
            return (view, window)
        }

        private func waitForPendingRebuild() async throws {
            for _ in 0 ..< 30 {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        @Test
        func `streamed text fades in`() {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            view.setContent(content(Self.paragraphs[0 ... 1].joined(separator: "\n\n")))
            #expect(view.streamLabel.isAnimating)
            #expect(view.content.blocks.count == 2)
            _ = window
        }

        /// With the tail closed, `**bo` already shows as bold, so `**bold`
        /// only appends to it and the new letters fade in.
        @Test
        func `streamed emphasis fades in as it grows`() {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            let intro = Self.paragraphs[0] + "\n\n"
            view.setContent(MarkdownContent(markdown: intro + "Hello **bo", isStreaming: true))
            view.setContent(MarkdownContent(markdown: intro + "Hello **bold", isStreaming: true))
            #expect(view.streamLabel.isAnimating)
            #expect(view.textLabelView.attributedText.string.hasSuffix("Hello bold\n"))
            _ = window
        }

        @Test
        func `content set immediately never animates`() {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            view.setContentImmediately(content(Self.paragraphs[0 ... 1].joined(separator: "\n\n")))
            #expect(!view.streamLabel.isAnimating)
            _ = window
        }

        @Test
        func `a view that is not streaming behaves like a plain markdown view`() {
            let (view, window) = makeHostedView()
            view.throttleInterval = nil
            view.setContent(content(Self.paragraphs[0 ... 1].joined(separator: "\n\n")))
            #expect(view.content.blocks.count == 2)
            #expect(!view.streamLabel.isAnimating)
            _ = window
        }

        @Test
        func `a view outside a window never animates`() {
            let view = MarkdownStreamView()
            view.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
            view.setContentImmediately(content(Self.paragraphs[0]))
            view.isStreaming = true
            view.setContent(content(Self.paragraphs[0 ... 1].joined(separator: "\n\n")))
            #expect(view.content.blocks.count == 2)
            #expect(!view.streamLabel.isAnimating)
        }

        @Test
        func `another item ends the animation and appears at once`() {
            let (view, window) = makeHostedView(identity: "first")
            view.isStreaming = true
            view.setContent(content(Self.paragraphs[0 ... 1].joined(separator: "\n\n")))
            #expect(view.streamLabel.isAnimating)
            view.streamIdentity = "second"
            #expect(!view.streamLabel.isAnimating)
            _ = window
        }

        @Test
        func `rebuilds are paced and ending the stream shows what is waiting`() async throws {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            // Far longer than the test, however busy the main actor is.
            view.rebuildIntervals = 1000 ... 1000
            view.setContent(content(Self.paragraphs[0 ... 1].joined(separator: "\n\n")))
            #expect(view.content.blocks.count == 2)
            // Inside the wait: held back.
            view.setContent(content(Self.paragraphs[0 ... 2].joined(separator: "\n\n")))
            view.setContent(content(Self.paragraphs[0 ... 3].joined(separator: "\n\n")))
            try await waitForPendingRebuild()
            #expect(view.content.blocks.count == 2, "\(view.content.blocks.count) blocks")
            view.isStreaming = false
            #expect(view.content.blocks.count == 4)
            _ = window
        }

        @Test
        func `content set immediately drops what the stream held back`() async throws {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            view.rebuildIntervals = 0.05 ... 0.05
            view.setContent(content(Self.paragraphs[0 ... 1].joined(separator: "\n\n")))
            view.setContent(content(Self.paragraphs[0 ... 2].joined(separator: "\n\n")))
            view.setContentImmediately(content("Replaced."))
            try await waitForPendingRebuild()
            #expect(view.content.blocks.count == 1)
            _ = window
        }

        @Test
        func `the wait between rebuilds follows their cost`() {
            let range: ClosedRange<TimeInterval> = (1.0 / 30) ... (1.0 / 8)
            #expect(MarkdownStreamView.rebuildInterval(forCost: 0.0005, load: 0.15, within: range) == 1.0 / 30)
            #expect(abs(MarkdownStreamView.rebuildInterval(forCost: 0.009, load: 0.15, within: range) - 0.06) < 1e-9)
            #expect(MarkdownStreamView.rebuildInterval(forCost: 0.05, load: 0.15, within: range) == 1.0 / 8)
        }

        @Test
        func `streamed code fades in inside its block`() {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            view.setContent(content("Intro.\n\n```swift\nlet a = 1\n"))
            let codeView = try? #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            #expect(codeView?.textView.animator != nil)
            view.setContent(content("Intro.\n\n```swift\nlet a = 1\nlet b = 2\n"))
            #expect(view.contextViews.compactMap { $0 as? CodeView }.first === codeView)
            #expect(codeView?.textView.isAnimating == true)
            view.isStreaming = false
            view.setContentImmediately(content("Intro.\n\n```swift\nlet a = 1\nlet b = 2\n```"))
            #expect(codeView?.textView.animator == nil)
            _ = window
        }

        @Test
        func `a finished highlight keeps streamed code fading`() throws {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            view.setContent(content("Intro.\n\n```swift\nlet a = 1\n"))
            view.setContent(content("Intro.\n\n```swift\nlet a = 1\nlet b = 2\n"))
            let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            #expect(codeView.textView.isAnimating)
            // The highlight arrives for the code already on screen: only colours change.
            let code = codeView.content
            codeView.setContent(code, highlightMap: [NSRange(location: 0, length: 3): .keyword])
            #expect(codeView.textView.isAnimating)
            _ = window
        }

        @Test
        func `the body keeps its inline code pill`() {
            let view = MarkdownStreamView()
            #expect(view.textLabelView.lineRenderer is InlineCodeLineRenderer)
        }

        // MARK: - Tables

        private static let table = "Intro.\n\n| Name | Value |\n| --- | --- |\n| alpha | 1"

        private func tableView(in view: MarkdownStreamView) throws -> TableView {
            try #require(view.contextViews.compactMap { $0 as? TableView }.first)
        }

        /// The table's cells, which a stream can animate only as animatable
        /// labels.
        private func animatableCells(of table: TableView) throws -> [LTXAnimatableLabel] {
            try table.cellViews.map { try #require($0 as? LTXAnimatableLabel) }
        }

        /// A stream view in a window that streams a table whose last cell
        /// just grew from `1` to `123`.
        private func makeStreamedTable() throws -> (MarkdownStreamView, HostWindow, TableView) {
            let (view, window) = makeHostedView()
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            view.setContent(content(Self.table))
            let table = try tableView(in: view)
            view.setContent(content(Self.table + "23"))
            #expect(try tableView(in: view) === table)
            return (view, window, table)
        }

        @Test
        func `streamed text fades in inside a table cell`() throws {
            let (_, window, table) = try makeStreamedTable()
            let cells = try animatableCells(of: table)
            #expect(cells.map(\.attributedText.string) == ["Name", "Value", "alpha", "123"])
            #expect(cells.last?.isAnimating == true)
            // Cells whose text did not change stay as they are.
            #expect(cells.dropLast().allSatisfy { !$0.isAnimating })
            _ = window
        }

        @Test
        func `a new table row fades in`() throws {
            let (view, window, table) = try makeStreamedTable()
            view.setContent(content(Self.table + "23\n| beta | 2"))
            let cells = try animatableCells(of: table)
            #expect(cells.count == 6)
            #expect(cells[safe: 4]?.attributedText.string == "beta")
            #expect(cells[safe: 4]?.isAnimating == true)
            #expect(cells[safe: 5]?.isAnimating == true)
            _ = window
        }

        @Test
        func `a table outside a window never animates`() throws {
            let view = MarkdownStreamView()
            view.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
            view.setContentImmediately(content(Self.paragraphs[0]))
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            view.setContent(content(Self.table))
            view.setContent(content(Self.table + "23\n| beta | 2"))
            let cells = try animatableCells(of: tableView(in: view))
            #expect(cells.count == 6)
            #expect(cells.allSatisfy { !$0.isAnimating })
        }

        @Test
        func `a table view taking another table shows it at once`() throws {
            let (view, window, table) = try makeStreamedTable()
            #expect(try animatableCells(of: table).last?.isAnimating == true)
            // Same place, another table: the pooled view takes it.
            view.setContent(content("Intro.\n\n| Fruit | Count |\n| --- | --- |\n| pear | 40"))
            #expect(try tableView(in: view) === table)
            let cells = try animatableCells(of: table)
            #expect(cells.map(\.attributedText.string) == ["Fruit", "Count", "pear", "40"])
            #expect(cells.allSatisfy { !$0.isAnimating })
            _ = window
        }

        @Test
        func `ending the stream lets a table's text in flight finish`() throws {
            let (view, window, table) = try makeStreamedTable()
            let cell = try #require(try animatableCells(of: table).last)
            view.isStreaming = false
            #expect(cell.isAnimating)
            view.setContentImmediately(content(Self.table + "23"))
            #expect(cell.animator == nil)
            #expect(!cell.isAnimating)
            _ = window
        }

        @Test
        func `another item ends the animations inside its blocks`() throws {
            let (view, window, table) = try makeStreamedTable()
            view.setContent(content(Self.table + "23\n\n```swift\nlet a = 1\n"))
            view.setContent(content(Self.table + "23\n\n```swift\nlet a = 1\nlet b = 2\n"))
            let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            #expect(try animatableCells(of: table).last?.isAnimating == true)
            #expect(codeView.textView.isAnimating)
            view.streamIdentity = "another"
            #expect(try animatableCells(of: table).allSatisfy { !$0.isAnimating })
            #expect(!codeView.textView.isAnimating)
            // The other item's text, streamed into the same views, shows at once.
            view.setContent(content(Self.table + "234\n\n```swift\nlet a = 1\nlet b = 2\nlet c = 3\n"))
            #expect(try animatableCells(of: table).allSatisfy { !$0.isAnimating })
            #expect(!codeView.textView.isAnimating)
            _ = window
        }

        // MARK: - The effect blocks fade in with

        @Test
        func `blocks fade in the way the body does`() throws {
            let (view, window) = makeHostedView()
            let configuration = LTXFadeInAnimator.Configuration(duration: 0.5, curve: .linear, maxBatches: 32)
            view.animator = LTXFadeInAnimator(configuration: configuration)
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            view.setContent(content(Self.table + "\n\n```swift\nlet a = 1\n"))
            let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            let labels = try [codeView.textView] + animatableCells(of: tableView(in: view))
            for label in labels {
                let animator = try #require(label.animator as? LTXFadeInAnimator)
                #expect(animator.configuration == configuration)
                #expect(animator !== view.animator)
            }
            // Every label keeps a timeline of its own.
            let animators = Set(labels.compactMap { $0.animator.map { ObjectIdentifier($0) } })
            #expect(animators.count == labels.count)
            _ = window
        }

        @Test
        func `a new body effect reaches the blocks`() throws {
            let (view, window, table) = try makeStreamedTable()
            let cell = try #require(try animatableCells(of: table).last)
            let configuration = LTXFadeInAnimator.Configuration(duration: 1)
            view.animator = LTXFadeInAnimator(configuration: configuration)
            #expect(!cell.isAnimating)
            view.setContent(content(Self.table + "234"))
            #expect((cell.animator as? LTXFadeInAnimator)?.configuration == configuration)
            #expect(cell.isAnimating)
            _ = window
        }

        @Test
        func `without a body effect blocks show their text at once`() throws {
            let (view, window) = makeHostedView()
            view.animator = nil
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            view.setContent(content(Self.table))
            view.setContent(content(Self.table + "23"))
            let cells = try animatableCells(of: tableView(in: view))
            #expect(cells.allSatisfy { $0.animator == nil && !$0.isAnimating })
            _ = window
        }

        @Test
        func `a subclass gives blocks an effect of its own`() throws {
            let frame = CGRect(x: 0, y: 0, width: 400, height: 600)
            let view = BlockEffectStreamView()
            view.frame = frame
            #if canImport(UIKit)
                let window = UIWindow(frame: frame)
                window.addSubview(view)
            #elseif canImport(AppKit)
                let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: true)
                window.contentView = view
            #endif
            view.setContentImmediately(content(Self.paragraphs[0]))
            view.isStreaming = true
            view.rebuildIntervals = 0 ... 0
            view.setContent(content(Self.table + "\n\n```swift\nlet a = 1\n"))
            view.setContent(content(Self.table + "23\n\n```swift\nlet a = 1\nlet b = 2\n"))
            let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            let cells = try animatableCells(of: tableView(in: view))
            #expect(codeView.textView.animator is BlockEffect)
            #expect(codeView.textView.isAnimating)
            #expect(cells.allSatisfy { $0.animator is BlockEffect })
            #expect(cells.last?.isAnimating == true)
            #expect(!(view.animator is BlockEffect))
            _ = window
        }
    }

    /// Stands for an effect of a subclass's own.
    @MainActor
    private final class BlockEffect: LTXFadeInAnimator {}

    @MainActor
    private final class BlockEffectStreamView: MarkdownStreamView {
        override func makeBlockAnimator() -> (any LTXTextAnimator)? {
            BlockEffect()
        }
    }
#endif
