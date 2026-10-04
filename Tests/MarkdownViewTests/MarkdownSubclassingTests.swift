import CoreText
import Litext
// Deliberately not `@testable`: these subclasses see only what an app sees,
// so the file stops compiling if a member they override is no longer open.
import MarkdownView
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    struct MarkdownSubclassingTests {
        @MainActor
        @Test
        func `A subclass hears the label's delegate calls`() {
            let view = SelectionObservingView()
            view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            view.setMarkdown("Some words")
            view.textLabelView.delegate?.textLabelView(view.textLabelView, didChangeSelection: nil)
            #expect(view.selectionChanges == 1)
        }

        @MainActor
        @Test
        func `A subclass sees theme changes`() {
            let view = SelectionObservingView()
            var theme = MarkdownTheme.default
            theme.fonts.body = .systemFont(ofSize: 21)
            view.theme = theme
            #expect(view.themeChanges == 1)
        }

        @MainActor
        @Test
        func `A label subclass draws through its own layout and keeps the pills`() throws {
            let label = LineCountingLabel()
            let view = MarkdownTextView(textLabelView: label)
            view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            view.setMarkdown("run `swift test` now")
            view.layoutSubtreeIfNeeded()

            let layout = try #require(label.textLayout as? LineCountingLayout)
            let size = label.bounds.size
            let context = try #require(CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ))
            layout.draw(in: context)
            #expect(layout.drawnLines > 0)
            #expect(layout.pillPasses == layout.drawnLines)
        }
    }

    private final class SelectionObservingView: MarkdownTextView {
        var selectionChanges = 0
        var themeChanges = 0

        override var theme: MarkdownTheme {
            didSet { themeChanges += 1 }
        }

        override func textLabelView(_ label: TextLabelView, didChangeSelection selection: NSRange?) {
            super.textLabelView(label, didChangeSelection: selection)
            selectionChanges += 1
        }
    }

    private final class LineCountingLabel: MarkdownTextLabelView {
        override func makeTextLayout(_ attributedText: NSAttributedString) -> TextLabel.Layout {
            LineCountingLayout(attributedString: attributedText)
        }
    }

    private final class LineCountingLayout: MarkdownTextLayout {
        var drawnLines = 0
        var pillPasses = 0

        override func draw(line: CTLine, at index: Int, in context: CGContext) {
            drawnLines += 1
            super.draw(line: line, at: index, in: context)
        }

        override func drawInlineCodeBackgrounds(of line: CTLine, at index: Int, in context: CGContext) {
            pillPasses += 1
            super.drawInlineCodeBackgrounds(of: line, at: index, in: context)
        }
    }
#endif
