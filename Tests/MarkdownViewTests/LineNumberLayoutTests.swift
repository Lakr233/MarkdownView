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

    /// Drawn into a context that already holds the code block's background,
    /// as a snapshot, PDF or print draws it, the gutter keeps that background
    /// rather than clearing it to black.
    @MainActor
    @Test
    func `The gutter draws over what is beneath it`() throws {
        let numbers = try #require(codeView(lines: 3)).lineNumberView
        let width = Int(numbers.bounds.width)
        let height = Int(numbers.bounds.height)
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ))
        context.setFillColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        #if canImport(UIKit)
            UIGraphicsPushContext(context)
            numbers.draw(numbers.bounds)
            UIGraphicsPopContext()
        #elseif canImport(AppKit)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            numbers.draw(numbers.bounds)
            NSGraphicsContext.restoreGraphicsState()
        #endif

        // A corner inside the padding, where no number is drawn.
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        #expect(pixels[3] == 255)
        #expect(pixels[0] == 51)
    }
}
