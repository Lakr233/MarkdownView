@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A streamed line grows wider without adding a line, so the code view keeps
/// its frame while what it holds no longer fits the layout it last did.
struct CodeViewLayoutTests {
    @MainActor
    private func markdown(_ code: String) -> String {
        """
        ```swift
        \(code)
        ```
        """
    }

    @MainActor
    private func codeView(in view: MarkdownTextView) -> CodeView? {
        view.contextViews.compactMap { $0 as? CodeView }.first
    }

    @MainActor
    @Test
    func `A longer line on the same line count widens the scrollable text`() {
        let view = RenderProbe.view(markdown("let a = 1\nlet b = 2"), width: 320)
        guard let before = codeView(in: view) else {
            Issue.record("no code view was built")
            return
        }
        let frameBefore = before.frame

        let long = String(repeating: "x", count: 200)
        RenderProbe.show(markdown("let a = 1\nlet b = \"\(long)\""), in: view, width: 320)
        guard let after = codeView(in: view) else {
            Issue.record("the code view went away")
            return
        }

        // The finding is about a reused view whose frame did not move.
        #expect(after === before)
        #expect(after.frame == frameBefore)

        let needed = after.textView.intrinsicContentSize.width
        #expect(after.textView.frame.width >= needed - 0.5)
    }

    @MainActor
    @Test
    func `A changed language relayouts its label`() {
        let view = RenderProbe.view(markdown("let a = 1"), width: 320)
        guard let before = codeView(in: view) else {
            Issue.record("no code view was built")
            return
        }
        let other = """
        ```a-considerably-longer-language-name
        let a = 1
        ```
        """
        RenderProbe.show(other, in: view, width: 320)
        guard let after = codeView(in: view) else {
            Issue.record("the code view went away")
            return
        }
        #expect(after === before)
        #expect(after.languageLabel.frame.width >= after.languageLabel.intrinsicContentSize.width - 0.5)
    }

    @MainActor
    @Test
    func `A code block without a language is labelled as code`() {
        let view = RenderProbe.view("```\nlet a = 1\n```", width: 320)
        guard let codeView = codeView(in: view) else {
            Issue.record("no code view was built")
            return
        }
        #expect(codeView.languageLabel.text == "</>")
    }
}
