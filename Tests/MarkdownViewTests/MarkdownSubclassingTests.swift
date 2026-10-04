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
        func `A label subclass with a layout of its own keeps the pills`() throws {
            let label = OwnLayoutLabel()
            let view = MarkdownTextView(textLabelView: label)
            view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            view.setMarkdown("run `swift test` now")
            view.layoutSubtreeIfNeeded()

            let layout = try #require(label.textLayout as? LineCountingLayout)
            let withPills = try render(layout, size: label.bounds.size)
            #expect(layout.drawnLines > 0)
            layout.lineRenderer = nil
            #expect(try render(layout, size: label.bounds.size) != withPills)
        }

        @MainActor
        @Test
        func `A plain label is given the inline code renderer`() {
            let view = MarkdownTextView(textLabelView: TextLabelView())
            #expect(view.textLabelView.lineRenderer is InlineCodeLineRenderer)
        }

        @MainActor
        @Test
        func `A label's own renderer is kept and draws behind the lines`() throws {
            let label = TextLabelView()
            let renderer = CountingRenderer()
            label.lineRenderer = renderer
            let view = MarkdownTextView(textLabelView: label)
            view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            view.setMarkdown("run `swift test` now")
            view.layoutSubtreeIfNeeded()
            #expect(label.lineRenderer === renderer)
            _ = try render(label.textLayout, size: label.bounds.size)
            #expect(renderer.backgrounds > 0)
        }
    }

    @MainActor
    private func render(_ layout: TextLabel.Layout, size: CGSize) throws -> [UInt8] {
        let width = Int(size.width)
        let height = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ))
            layout.draw(in: context)
        }
        return bytes
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

    private final class OwnLayoutLabel: MarkdownTextLabelView {
        override func makeTextLayout(_ attributedText: NSAttributedString) -> TextLabel.Layout {
            LineCountingLayout(attributedString: attributedText)
        }
    }

    private final class LineCountingLayout: TextLabel.Layout {
        var drawnLines = 0

        override func draw(line: CTLine, at index: Int, in context: CGContext) {
            drawnLines += 1
            super.draw(line: line, at: index, in: context)
        }
    }

    private final class CountingRenderer: InlineCodeLineRenderer {
        var backgrounds = 0

        override func drawBackground(of line: CTLine, at index: Int, in context: CGContext, layout: TextLabel.Layout) {
            backgrounds += 1
            super.drawBackground(of: line, at: index, in: context, layout: layout)
        }
    }
#endif
