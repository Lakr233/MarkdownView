@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The code's lines are spaced apart, with no spacing after the last one, so
/// a number centred on an even share of the height drifts off its line: low
/// on the first line, high on the last.
struct LineNumberLayoutTests {
    @MainActor
    private func codeView(lines: Int) -> CodeView? {
        let code = (1 ... lines).map { "let value\($0) = \($0)" }.joined(separator: "\n")
        let view = RenderProbe.view("```swift\n\(code)\n```", width: 480)
        return view.contextViews.compactMap { $0 as? CodeView }.first
    }

    @MainActor
    @Test
    func `Each number is centred on its code line`() throws {
        let single = try #require(codeView(lines: 1))
        let lineHeight = single.textView.intrinsicContentSize.height

        let block = try #require(codeView(lines: 11))
        let numbers = block.lineNumberView
        let contentHeight = block.textView.intrinsicContentSize.height
        let top = CodeViewConfiguration.codePadding

        #expect(abs(numbers.lineMidY(1) - (top + lineHeight / 2)) < 0.5)
        #expect(abs(numbers.lineMidY(11) - (top + contentHeight - lineHeight / 2)) < 0.5)
    }
}
