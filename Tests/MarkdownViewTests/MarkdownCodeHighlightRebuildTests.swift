import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Every view rebuilds its whole document whenever any code block anywhere
/// finishes highlighting, which is the other place streaming pays twice. A
/// narrower rule — rebuild only for a block this view is showing — has to leave
/// the outcome untouched, so these check the outcome and not the trigger.
struct MarkdownCodeHighlightRebuildTests {
    private static let source = """
    func greet(_ name: String) -> String {
        "hello, \\(name)"
    }
    """

    @MainActor
    private func markdown(_ code: String, language: String = "swift") -> String {
        """
        Before the code.

        ```\(language)
        \(code)
        ```

        After the code.
        """
    }

    /// Fills the shared highlight cache for every code block in `markdown`.
    ///
    /// Keyed off the parsed block rather than the source text: the key is taken
    /// before the block's trailing newline is trimmed, so warming it by hand
    /// with the visible code lands under a key nothing ever looks up.
    @MainActor
    private func warmHighlightCache(for markdown: String) {
        for case let .codeBlock(language, content) in MarkdownParser().parse(markdown).document {
            _ = CodeHighlighter.current.highlight(
                key: CodeHighlighter.current.key(for: content, language: language),
                content: content,
                language: language
            )
        }
    }

    @MainActor
    private func codeView(in view: MarkdownTextView) -> CodeView? {
        view.contextViews.compactMap { $0 as? CodeView }.first
    }

    @MainActor
    private func distinctColors(in codeView: CodeView) -> Set<String> {
        let text = codeView.textView.attributedText
        var colors: Set<String> = []
        text.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, _, _ in
            guard let color = value as? PlatformColor else { return }
            colors.insert(String(describing: color))
        }
        return colors
    }

    @MainActor
    @Test("A cached highlight map colors the code on the first build")
    func cachedHighlightMapColorsTheCode() {
        // Warm the shared cache synchronously so the build does not depend on
        // the asynchronous worker landing in time.
        warmHighlightCache(for: markdown(Self.source))

        let view = RenderProbe.view(markdown(Self.source))
        guard let codeView = codeView(in: view) else {
            Issue.record("no code view was built")
            return
        }

        #expect(codeView.textView.attributedText.string.contains("func greet"))
        #expect(distinctColors(in: codeView).count > 1)
    }

    @MainActor
    @Test("A highlight update leaves the document unchanged")
    func highlightUpdateLeavesTheDocumentUnchanged() {
        warmHighlightCache(for: markdown(Self.source))
        let view = RenderProbe.view(markdown(Self.source))
        RenderProbe.show(markdown(Self.source), in: view)

        let before = RenderProbe.digest(view.textLabelView.attributedText)
        let codeViewBefore = codeView(in: view)

        NotificationCenter.default.post(
            name: CodeHighlighter.highlightDidUpdateNotification,
            object: nil
        )
        RenderProbe.layout(view)

        let after = RenderProbe.digest(view.textLabelView.attributedText)
        #expect(before == after, "\(RenderProbe.firstDifference(before, after))")
        #expect(codeView(in: view) === codeViewBefore)
        #expect(view.contextViews.compactMap { $0 as? CodeView }.count == 1)
    }

    @MainActor
    @Test("A highlight update for another document leaves this one alone")
    func unrelatedHighlightUpdateLeavesThisViewAlone() {
        let view = RenderProbe.view(markdown(Self.source))
        RenderProbe.show(markdown(Self.source), in: view)
        let before = RenderProbe.digest(view.textLabelView.attributedText)

        // Highlighting a block this view never showed still posts the shared
        // notification.
        _ = CodeHighlighter.current.highlight(
            key: nil,
            content: "print(\"a completely different program\")",
            language: "python"
        )
        NotificationCenter.default.post(
            name: CodeHighlighter.highlightDidUpdateNotification,
            object: nil
        )
        RenderProbe.layout(view)

        let after = RenderProbe.digest(view.textLabelView.attributedText)
        #expect(before == after, "\(RenderProbe.firstDifference(before, after))")
    }

    @MainActor
    @Test("Code text reaches the view verbatim")
    func codeTextReachesTheViewVerbatim() {
        let view = RenderProbe.view(markdown(Self.source))
        guard let codeView = codeView(in: view) else {
            Issue.record("no code view was built")
            return
        }

        #expect(codeView.textView.attributedText.string == Self.source)
        #expect(codeView.language == "swift")
    }

    @MainActor
    @Test("A code block without a language still renders its source")
    func codeWithoutLanguageStillRenders() {
        let view = RenderProbe.view("""
        ```
        plain fenced text
        ```
        """)
        guard let codeView = codeView(in: view) else {
            Issue.record("no code view was built")
            return
        }

        #expect(codeView.textView.attributedText.string == "plain fenced text")
    }

    @MainActor
    @Test("Streaming a code block ends with its full source")
    func streamedCodeBlockEndsComplete() {
        let final = markdown(Self.source)
        let view = MarkdownTextView()

        let characters = Array(final)
        let step = max(1, characters.count / 16)
        var cursor = 0
        while cursor < characters.count {
            cursor = min(characters.count, cursor + step)
            RenderProbe.show(String(characters[0 ..< cursor]), in: view)
        }

        guard let codeView = codeView(in: view) else {
            Issue.record("no code view was built")
            return
        }
        #expect(codeView.textView.attributedText.string == Self.source)
    }

    @MainActor
    @Test("A code block replaced by a paragraph releases its view")
    func codeReplacedByTextReleasesItsView() {
        let view = RenderProbe.view(markdown(Self.source))
        #expect(codeView(in: view) != nil)

        RenderProbe.show("Just a paragraph now.", in: view)

        let strayVisible = view.subviews.compactMap { $0 as? CodeView }.filter { !$0.isHidden }
        #expect(codeView(in: view) == nil)
        #expect(strayVisible.isEmpty)
    }

    @MainActor
    @Test("The same source in two languages is cached apart")
    func sameSourceInTwoLanguagesIsCachedApart() {
        // The highlight cache is keyed on content and language together; keying
        // it on content alone would paint one language with the other's colors.
        let source = "class Thing: pass"
        let pythonKey = CodeHighlighter.current.key(for: source, language: "python")
        let swiftKey = CodeHighlighter.current.key(for: source, language: "swift")

        #expect(pythonKey != swiftKey)

        _ = CodeHighlighter.current.highlight(key: pythonKey, content: source, language: "python")
        #expect(CodeHighlighter.current.cachedHighlightMap(for: pythonKey) != nil)
        #expect(CodeHighlighter.current.cachedHighlightMap(for: swiftKey) == nil)
    }

    @MainActor
    @Test("A language differing only in case shares one cache entry")
    func languageCaseDoesNotSplitTheCache() {
        let source = "let a = 1"
        #expect(
            CodeHighlighter.current.key(for: source, language: "Swift")
                == CodeHighlighter.current.key(for: source, language: "swift")
        )
    }
}
