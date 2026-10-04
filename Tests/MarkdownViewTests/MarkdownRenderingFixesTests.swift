@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// What a reader sees for list numbers, headings, locales and math.
struct MarkdownRenderingFixesTests {
    /// An item that opens with a nested list, or is empty, still takes its
    /// number, so the item after it is not renumbered.
    @MainActor
    @Test(arguments: [
        "1. - a\n2. b",
        "1.\n2. b",
    ])
    func `Ordered items after one without a leading paragraph keep their number`(_ markdown: String) {
        let text = RenderProbe.show(markdown, in: MarkdownTextView())
        let markers = RenderProbe.attachmentTexts(in: text)
        #expect(markers.contains("2. "), "\(markers)")
    }

    @MainActor
    @Test
    func `Inline code in a heading keeps its monospaced font`() {
        let text = RenderProbe.show("# Call `foo()`", in: MarkdownTextView())
        let font = RenderProbe.font(at: "foo", in: text)
        #if canImport(UIKit)
            #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
        #elseif canImport(AppKit)
            #expect(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true)
        #endif
    }

    /// Ideographs alone say nothing about the language; the content's locale
    /// does. A heading must pick the same face for them as a paragraph.
    @MainActor
    @Test
    func `A heading picks its fallback font in the content's locale`() {
        let locale = Locale(identifier: "ja_JP")
        let heading = RenderProbe.show("# 漢字", in: MarkdownTextView(), locale: locale)
        let body = RenderProbe.show("漢字", in: MarkdownTextView(), locale: locale)
        #expect(
            RenderProbe.font(at: "漢字", in: heading)?.familyName
                == RenderProbe.font(at: "漢字", in: body)?.familyName,
        )
    }

    @MainActor
    @Test
    func `Changing only the locale does not reuse fragments built for the old one`() {
        let markdown = "漢字の段落\n\n漢字"
        let reused = MarkdownTextView()
        RenderProbe.show(markdown, in: reused, locale: .init(identifier: "zh_CN"))
        let after = RenderProbe.show(markdown, in: reused, locale: .init(identifier: "ja_JP"))
        let fresh = RenderProbe.show(markdown, in: MarkdownTextView(), locale: .init(identifier: "ja_JP"))
        let lhs = RenderProbe.digest(after)
        let rhs = RenderProbe.digest(fresh)
        #expect(lhs == rhs, "\(RenderProbe.firstDifference(lhs, rhs))")
    }

    /// A test runner, like a command-line tool, never creates `NSApp`.
    @MainActor
    @Test
    func `Math renders without an application object`() {
        #expect(MathRenderer.renderToImage(latex: "x") != nil)
    }

    @MainActor
    @Test(arguments: [
        "a \\dots b",
        "a \\dotsb b",
        "a \\dotsc b",
        "a \\dotsi b",
        "a \\dotsm b",
        "a \\dotso b",
        "\\dots\\dotsc",
    ])
    func `Every amsmath dots command renders`(_ latex: String) {
        #expect(MathRenderer.renderToImage(latex: latex) != nil)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        @MainActor
        @Test
        func `Math is drawn in the theme's body colour`() throws {
            var theme = MarkdownTheme.default
            theme.colors.body = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
            let view = RenderProbe.view("$x+y=z$", width: 200, theme: theme)
            view.appearance = NSAppearance(named: .aqua)
            let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)

            var red = 0
            var dark = 0
            for x in 0 ..< rep.pixelsWide {
                for y in 0 ..< rep.pixelsHigh {
                    guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                          color.alphaComponent > 0.5
                    else { continue }
                    if color.redComponent > 0.6, color.greenComponent < 0.3 {
                        red += 1
                    }
                    if color.redComponent < 0.3, color.greenComponent < 0.3, color.blueComponent < 0.3 {
                        dark += 1
                    }
                }
            }
            #expect(red > 0)
            #expect(dark == 0)
        }
    #endif
}
