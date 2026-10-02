@testable import MarkdownView
import SwiftUI
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    /// What a host sees of a `MarkdownTextView` it configures from the
    /// outside: handlers, throttling, Auto Layout, SwiftUI content switches and
    /// drag-select scrolling.
    struct MarkdownTextViewHostingTests {
        private static let codeAndTable = """
        ```swift
        let answer = 42
        ```

        | A | B |
        | - | - |
        | [link](https://example.com) | 2 |
        """

        @MainActor
        @Test
        func `Handlers set after content reach the code and table views`() {
            let view = RenderProbe.view(Self.codeAndTable)
            let codeView = view.contextViews.compactMap { $0 as? CodeView }.first
            let tableView = view.contextViews.compactMap { $0 as? TableView }.first
            #expect(codeView?.previewAction == nil)

            view.codePreviewHandler = { _, _ in }
            view.linkHandler = { _, _, _ in }

            #expect(codeView?.previewAction != nil)
            #expect(tableView?.linkHandler != nil)

            view.codePreviewHandler = nil
            #expect(codeView?.previewAction == nil)
        }

        @MainActor
        @Test
        func `A selection across a code block or table tints them, and only while it covers them`() throws {
            let view = RenderProbe.view("before\n\n" + Self.codeAndTable + "\n\nafter")
            let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            let tableView = try #require(view.contextViews.compactMap { $0 as? TableView }.first)
            func isTinted(_ view: NSView) -> Bool {
                view.layer?.sublayers?.contains { $0.name == "MarkdownView.selectionTint" } ?? false
            }
            let text = view.textLabelView.attributedText.string as NSString

            view.textLabelView.selectionRange = NSRange(location: 0, length: text.length)
            #expect(isTinted(codeView))
            #expect(isTinted(tableView))

            view.textLabelView.selectionRange = text.range(of: "before")
            #expect(!isTinted(codeView))
            #expect(!isTinted(tableView))

            view.textLabelView.selectionRange = NSRange(location: 0, length: text.length)
            view.textLabelView.selectionRange = nil
            #expect(!isTinted(tableView))
        }

        @MainActor
        @Test
        func `Changing the throttle interval keeps the pending content`() async throws {
            let view = MarkdownTextView()
            view.throttleInterval = 0.5
            view.setContent(RenderProbe.content("first"))
            view.setContent(RenderProbe.content("second"))
            view.throttleInterval = nil

            try await Task.sleep(nanoseconds: 700_000_000)
            #expect(view.textLabelView.attributedText.string.contains("second"))
        }

        @MainActor
        @Test
        func `An Auto Layout host grows with new content`() {
            let container = NSView(frame: .init(x: 0, y: 0, width: 300, height: 2000))
            let view = MarkdownTextView()
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.topAnchor.constraint(equalTo: container.topAnchor),
            ])
            view.setContentImmediately(RenderProbe.content("short"))
            container.layoutSubtreeIfNeeded()
            let shortHeight = view.frame.height

            let longText = Array(
                repeating: "A paragraph long enough to wrap and add real height.",
                count: 12,
            ).joined(separator: "\n\n")
            view.setContentImmediately(RenderProbe.content(longText))
            container.layoutSubtreeIfNeeded()

            #expect(view.frame.height > shortHeight)
            #expect(abs(view.frame.height - view.boundingSize(for: 300).height) < 1)
        }

        @MainActor
        @Test
        func `Switching from content to empty text clears the document`() throws {
            let window = NSWindow(
                contentRect: .init(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: true,
            )
            let content = RenderProbe.content("old document")
            let host = NSHostingView(rootView: MarkdownView(content))
            window.contentView = host
            host.layoutSubtreeIfNeeded()

            let view = try #require(firstMarkdownTextView(in: host))
            #expect(view.textLabelView.attributedText.string.contains("old document"))

            host.rootView = MarkdownView("")
            host.layoutSubtreeIfNeeded()

            #expect(!view.textLabelView.attributedText.string.contains("old document"))
        }

        @MainActor
        @Test
        func `Drag-select autoscroll honours the scroll view's content insets`() {
            let scrollView = NSScrollView(frame: .init(x: 0, y: 0, width: 300, height: 200))
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.contentInsets = .init(top: 40, left: 0, bottom: 40, right: 0)
            let longText = Array(
                repeating: "A paragraph long enough to wrap and add real height.",
                count: 20,
            ).joined(separator: "\n\n")
            let view = RenderProbe.view(longText, width: 300)
            scrollView.documentView = view
            view.trackedScrollView = scrollView
            let clipView = scrollView.contentView

            // Scrolled to the very top: the clip view sits above the document
            // by the top inset. Dragging above it must not scroll down.
            clipView.scroll(to: .init(x: 0, y: -40))
            scrollView.reflectScrolledClipView(clipView)
            #expect(clipView.bounds.minY == -40)
            view.textLabelView(view.textLabelView, didDragSelectionAt: .init(x: 10, y: -200))
            #expect(clipView.bounds.minY == -40)

            // Dragging 5pt into the bottom edge zone scrolls by 5pt, not by
            // that plus the top inset.
            let edge = scrollView.documentVisibleRect.maxY - 16
            view.textLabelView(view.textLabelView, didDragSelectionAt: .init(x: 10, y: edge + 5))
            #expect(abs(clipView.bounds.minY - (-40 + 5)) < 0.5)

            // Dragging far below must reach the bottom inset.
            view.textLabelView(
                view.textLabelView,
                didDragSelectionAt: .init(x: 10, y: view.bounds.height + 1000),
            )
            let bottom = view.bounds.height + 40 - clipView.bounds.height
            #expect(abs(clipView.bounds.minY - bottom) < 0.5)
        }

        @MainActor
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
    }
#endif
