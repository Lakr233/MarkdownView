@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The newline that ends a paragraph, a heading or a list item is in the body font.
///
/// A newline given no font is typeset in CoreText's default, Helvetica 12 —
/// which is also what `fixAttributes` writes onto it. From iOS 27 and macOS 27
/// that is visible: after a block that ends in a full-width closing bracket
/// (`」`, `）`), a newline in another font moves half an em to the start of the
/// next line, so the paragraph that follows begins indented by half a
/// character. With the newline in the body font nothing moves.
struct MarkdownBlockBreakFontTests {
    @MainActor
    @Test(arguments: [
        "他说：「好。」\n\n下一段。",
        "# 标题（一）\n\n下一段。",
        "- 第一项（甲）\n- 第二项\n\n下一段。",
        "1. 第一项「甲」\n2. 第二项\n\n下一段。",
    ])
    func `A block's newline is in the body font`(markdown: String) throws {
        let theme = MarkdownTheme.default
        let built = RenderProbe.show(markdown, in: MarkdownTextView(), theme: theme)
        let text = built.string as NSString
        var newlines = 0
        for index in 0 ..< text.length where text.character(at: index) == 0x0A {
            newlines += 1
            let font = try #require(built.attribute(.font, at: index, effectiveRange: nil) as? PlatformFont)
            #expect(
                font.fontName == theme.fonts.body.fontName && font.pointSize == theme.fonts.body.pointSize,
                "the newline at \(index), after \(text.substring(to: index).suffix(4).debugDescription), is in \(font.fontName) \(font.pointSize)",
            )
        }
        #expect(newlines > 0)
    }
}
