@testable import MarkdownView
import SwiftUI
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    struct MarkdownViewStreamingHeightTests {
        @MainActor
        private func firstMarkdownTextView(in view: NSView) -> MarkdownTextView? {
            var queue: [NSView] = [view]
            while !queue.isEmpty {
                let view = queue.removeFirst()
                if let match = view as? MarkdownTextView { return match }
                queue.append(contentsOf: view.subviews)
            }
            return nil
        }

        @MainActor
        @Test("Deferred throttled apply still grows the hosted height")
        func deferredApplyGrowsHostedHeight() async throws {
            let window = NSWindow(
                contentRect: .init(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: true
            )
            let host = NSHostingView(rootView: ScrollView { MarkdownView("short") })
            window.contentView = host
            host.layoutSubtreeIfNeeded()

            let view = try #require(firstMarkdownTextView(in: host))
            let initialHeight = view.frame.height
            #expect(initialHeight > 0)

            let longText = Array(
                repeating: "A paragraph long enough to wrap and add real height.",
                count: 12
            ).joined(separator: "\n\n")

            // Two updates inside one throttle window: the first applies
            // synchronously, the second is deferred past the interval and
            // lands outside any SwiftUI update cycle.
            host.rootView = ScrollView { MarkdownView("short but changed") }
            host.layoutSubtreeIfNeeded()
            host.rootView = ScrollView { MarkdownView(longText) }
            host.layoutSubtreeIfNeeded()
            let heightBeforeDeferred = view.frame.height

            // Let the deferred apply fire and any follow-up layout settle.
            for _ in 0 ..< 30 {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            host.layoutSubtreeIfNeeded()

            print("[dbg] initial=\(initialHeight) beforeDeferred=\(heightBeforeDeferred) final=\(view.frame.height) content=\(view.textLabelView.intrinsicContentSize)")
            #expect(view.frame.height >= view.textLabelView.intrinsicContentSize.height - 0.5)
            #expect(view.frame.height > initialHeight)
        }
    }
#endif
