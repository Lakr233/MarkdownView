@testable import MarkdownView
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    struct InlineCodeTests {
        @MainActor
        @Test("A line holding inline code is as tall as one without")
        func lineHeightIsUnchanged() {
            let plain = RenderProbe.view("plain words here", width: 480)
            let code = RenderProbe.view("plain `code` here", width: 480)
            #expect(abs(plain.boundingSize(for: 480).height - code.boundingSize(for: 480).height) < 0.5)
        }

        @MainActor
        @Test("Copying inline code gives back the code alone")
        func copiesWithoutSpacers() {
            let view = RenderProbe.view("run `swift test` now", width: 480)
            let label = view.textLabelView
            label.selectionRange = NSRange(location: 0, length: label.attributedText.length)
            #expect(label.selectedPlainText()?.contains("run swift test now") == true)
        }

        @Test("Only <br> reads as a line break")
        func lineBreakTags() {
            #expect(InlineCode.isLineBreak("<br>"))
            #expect(InlineCode.isLineBreak("<BR />"))
            #expect(!InlineCode.isLineBreak("<b>"))
        }
    }
#endif
