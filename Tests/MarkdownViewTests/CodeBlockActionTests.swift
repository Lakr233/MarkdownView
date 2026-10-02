@testable import MarkdownView
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    @MainActor
    private final class Provider: CodeBlockActionProvider {
        var asked: [String?] = []
        var tapped: [CodeBlock] = []

        func codeBlockActions(forLanguage language: String?) -> [CodeBlockAction] {
            asked.append(language)
            guard language == "html" else { return [] }
            return [CodeBlockAction(title: "Open", systemImage: "safari") { [weak self] block in
                self?.tapped.append(block)
            }]
        }
    }

    struct CodeBlockActionTests {
        @MainActor
        @Test
        func `Copy shows a checkmark, and a reused view starts without it`() {
            let view = CodeView()
            view.setContent("let a = 1", highlightMap: nil)
            let idle = view.copyButton.image

            // Not handleCopy, which would overwrite the clipboard of whoever runs the tests.
            view.showCopyFeedback()
            #expect(view.copyButton.image != idle)

            view.setContent("let b = 2", highlightMap: nil)
            #expect(view.copyButton.image?.tiffRepresentation == idle?.tiffRepresentation)
        }

        @MainActor
        @Test
        func `Copy goes back by itself`() {
            let view = CodeView()
            let idle = view.copyButton.image?.tiffRepresentation
            // Not handleCopy, which would overwrite the clipboard of whoever runs the tests.
            view.showCopyFeedback()
            RunLoop.main.run(until: Date().addingTimeInterval(CodeView.copyFeedbackDuration + 0.3))
            #expect(view.copyButton.image?.tiffRepresentation == idle)
        }

        @MainActor
        @Test
        func `A provider's buttons follow the language and get the content at tap time`() throws {
            let provider = Provider()
            let view = CodeView()
            view.language = "html"
            view.actionProvider = provider
            #expect(view.actionButtons.count == 1)

            view.setContent("<p>hi</p>", highlightMap: nil)
            let button = try #require(view.actionButtons.first)
            view.handleAction(button)
            #expect(provider.tapped == [CodeBlock(language: "html", content: "<p>hi</p>")])

            view.language = "swift"
            #expect(view.actionButtons.isEmpty)
            #expect(button.superview == nil)
            // Streaming content does not ask again; only provider and language changes do.
            let askedBefore = provider.asked.count
            view.setContent("let a = 1", highlightMap: nil)
            #expect(provider.asked.count == askedBefore)
        }

        @MainActor
        @Test
        func `MarkdownTextView hands its provider to code blocks`() throws {
            let provider = Provider()
            let view = RenderProbe.view("```html\n<b>x</b>\n```")
            view.codeBlockActionProvider = provider
            let codeView = try #require(view.contextViews.compactMap { $0 as? CodeView }.first)
            #expect(codeView.actionButtons.count == 1)
        }
    }
#endif
