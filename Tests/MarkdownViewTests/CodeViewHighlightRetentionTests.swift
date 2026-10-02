@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct CodeViewHighlightRetentionTests {
    @MainActor
    private func foregroundColor(in codeView: CodeView, at location: Int) -> PlatformColor? {
        let text = codeView.textView.attributedText
        guard location < text.length else { return nil }
        return text.attribute(.foregroundColor, at: location, effectiveRange: nil) as? PlatformColor
    }

    @MainActor
    @Test
    func `Streaming append keeps stale highlight until a fresh map arrives`() {
        let codeView = CodeView(frame: .init(x: 0, y: 0, width: 260, height: 160))
        codeView.theme = .default

        let keywordColor = MarkdownTheme.default.syntax.keyword
        let map: CodeHighlighter.HighlightMap = [NSRange(location: 0, length: 3): .keyword]
        codeView.setContent("let value = 1", highlightMap: map)
        #expect(foregroundColor(in: codeView, at: 0) == keywordColor)

        // A streaming append arrives before its highlight map is computed;
        // the previously colored prefix must not flash back to plain text.
        codeView.setContent("let value = 12", highlightMap: nil)
        #expect(foregroundColor(in: codeView, at: 0) == keywordColor)

        // A fresh map replaces the stale one.
        let freshColor = MarkdownTheme.default.syntax.type
        codeView.setContent("let value = 12", highlightMap: [NSRange(location: 0, length: 3): .type])
        #expect(foregroundColor(in: codeView, at: 0) == freshColor)
    }

    @MainActor
    @Test
    func `Unrelated content drops the stale highlight`() {
        let codeView = CodeView(frame: .init(x: 0, y: 0, width: 260, height: 160))
        codeView.theme = .default

        let keywordColor = MarkdownTheme.default.syntax.keyword
        codeView.setContent("let value = 1", highlightMap: [NSRange(location: 0, length: 3): .keyword])

        // Reused for a different document: stale colors must not be applied.
        codeView.setContent("print(value)", highlightMap: nil)
        #expect(foregroundColor(in: codeView, at: 0) != keywordColor)
    }

    @MainActor
    @Test
    func `The theme's syntax colours colour the code`() {
        let codeView = CodeView(frame: .init(x: 0, y: 0, width: 260, height: 160))
        var theme = MarkdownTheme.default
        theme.syntax.keyword = .systemGreen
        codeView.theme = theme
        codeView.setContent("let value = 1", highlightMap: [NSRange(location: 0, length: 3): .keyword])
        #expect(foregroundColor(in: codeView, at: 0) == PlatformColor.systemGreen)
    }
}
