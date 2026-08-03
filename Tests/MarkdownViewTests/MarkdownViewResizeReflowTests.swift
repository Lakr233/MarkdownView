@testable import MarkdownView
import SwiftUI
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    struct MarkdownViewResizeReflowTests {
        private static let document = """
        This is a demo paragraph with enough words to wrap several times when the \
        hosting window becomes narrow, so a stale layout width is easy to detect.
        """

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
        @Test("SwiftUI host reflows markdown text when the window shrinks")
        func hostReflowsOnWindowResize() throws {
            let window = NSWindow(
                contentRect: .init(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: true
            )
            let host = NSHostingView(
                rootView: ScrollView {
                    MarkdownView(Self.document)
                }
            )
            window.contentView = host
            host.layoutSubtreeIfNeeded()

            let view = try #require(firstMarkdownTextView(in: host))
            // Capture the geometry now: the same instance survives the
            // resize, so its frame must be read before and after.
            let wideFrame = view.frame
            #expect(wideFrame.width > 0)

            window.setContentSize(.init(width: 400, height: 600))
            host.layoutSubtreeIfNeeded()

            let narrowFrame = view.frame
            #expect(narrowFrame.width <= 400)
            // The text must re-wrap for the narrow width: same content at
            // roughly half the width has to occupy more vertical space.
            #expect(narrowFrame.height > wideFrame.height || wideFrame.width <= 400)
            #expect(view.textLabelView.frame.width <= narrowFrame.width + 0.5)
        }
    }
#endif
