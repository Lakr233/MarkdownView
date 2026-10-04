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
        func `the body keeps its inline code pill`() {
            let view = MarkdownStreamView()
            #expect(view.textLabelView.lineRenderer is InlineCodeLineRenderer)
        }
    }
#endif
