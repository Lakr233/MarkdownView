import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Body text is rendered through a cache keyed on the text, the locale and a
/// signature of the theme. The signature is rebuilt for every text node, which
/// is the first thing worth making cheaper — and the first thing that will
/// start handing back another theme's text if the key stops telling themes
/// apart.
///
/// These fix what the key has to distinguish, without saying how it is spelled.
struct MarkdownInlineCacheTests {
    @MainActor
    private func themeWithBodyFont(size: CGFloat) -> MarkdownTheme {
        var theme = MarkdownTheme.default
        #if canImport(UIKit)
            theme.fonts.body = .systemFont(ofSize: size)
        #elseif canImport(AppKit)
            theme.fonts.body = .systemFont(ofSize: size)
        #endif
        return theme
    }

    @MainActor
    private func themeWithBodyColor(_ color: PlatformColor) -> MarkdownTheme {
        var theme = MarkdownTheme.default
        theme.colors.body = color
        return theme
    }

    @MainActor
    @Test("The same text under two body fonts renders both fonts")
    func cacheDistinguishesBodyFont() {
        let content = RenderProbe.content("placeholder")
        let small = content.cachedBodyText("中文 text", theme: themeWithBodyFont(size: 12))
        let large = content.cachedBodyText("中文 text", theme: themeWithBodyFont(size: 24))

        let smallFont = small.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont
        let largeFont = large.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont

        #expect(smallFont?.pointSize == 12)
        #expect(largeFont?.pointSize == 24)
    }

    @MainActor
    @Test("The same text under two body colors renders both colors")
    func cacheDistinguishesBodyColor() {
        let content = RenderProbe.content("placeholder")
        let red = content.cachedBodyText("中文 text", theme: themeWithBodyColor(.systemRed))
        let blue = content.cachedBodyText("中文 text", theme: themeWithBodyColor(.systemBlue))

        let redColor = red.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor
        let blueColor = blue.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor

        #expect(redColor == PlatformColor.systemRed)
        #expect(blueColor == PlatformColor.systemBlue)
        #expect(redColor != blueColor)
    }

    @MainActor
    @Test("Repeating a lookup returns equal text")
    func repeatedLookupsAgree() {
        let content = RenderProbe.content("placeholder")
        let theme = MarkdownTheme.default
        let first = content.cachedBodyText("中文 text 日本語かな", theme: theme)
        let second = content.cachedBodyText("中文 text 日本語かな", theme: theme)

        #expect(first.isEqual(to: second))
    }

    @MainActor
    @Test("Different texts do not share an entry")
    func differentTextsDoNotCollide() {
        let content = RenderProbe.content("placeholder")
        let theme = MarkdownTheme.default

        #expect(content.cachedBodyText("first", theme: theme).string == "first")
        #expect(content.cachedBodyText("second", theme: theme).string == "second")
        #expect(content.cachedBodyText("", theme: theme).string.isEmpty)
    }

    /// The glyphs CoreText would actually draw for `text`.
    ///
    /// The locale reaches the reader as a shape, not as an attribute — the same
    /// codepoint is drawn differently in Simplified and Traditional Chinese —
    /// so that is what these assert. Whether the shape comes from a resolved
    /// font or from a language attribute left in place is not the point.
    @MainActor
    private func glyphs(of text: NSAttributedString) -> [CGGlyph] {
        let line = CTLineCreateWithAttributedString(text)
        var result: [CGGlyph] = []
        for run in (CTLineGetGlyphRuns(line) as NSArray) {
            let run = run as! CTRun
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            result.append(contentsOf: glyphs)
        }
        return result
    }

    /// Characters whose shape differs between Simplified and Traditional.
    private static let variantHan = "直骨門今雪類"

    @MainActor
    @Test("Han text is drawn the way its locale draws it")
    func hanTextFollowsTheLocale() {
        func drawn(_ localeIdentifier: String) -> [CGGlyph] {
            let content = RenderProbe.content("placeholder", locale: .init(identifier: localeIdentifier))
            return glyphs(of: content.cachedBodyText(Self.variantHan, theme: .default))
        }

        let simplified = drawn("zh-Hans")
        #expect(!simplified.isEmpty)
        #expect(drawn("zh-Hant") != simplified, "Traditional must not be drawn as Simplified")
        #expect(drawn("ja") != simplified, "Japanese must not be drawn as Simplified")
        #expect(drawn("en_US") == simplified, "an unknown locale falls back to Simplified")
    }

    @MainActor
    @Test("Only the languages that still change the result keep their attribute")
    func shapingLanguagesKeepTheirAttribute() {
        // The attribute triples the cost of building a framesetter, and it is
        // paid on every rebuild, so it is dropped once the font it selected has
        // been resolved. It stays for the two languages where dropping it was
        // measured to change what the reader sees: Traditional Chinese draws
        // 41% of ideographs differently, and Korean breaks lines differently.
        func language(_ localeIdentifier: String, _ text: String) -> String? {
            let content = RenderProbe.content("placeholder", locale: .init(identifier: localeIdentifier))
            return content.cachedBodyText(text, theme: .default)
                .attribute(.coreTextLanguage, at: 0, effectiveRange: nil) as? String
        }

        #expect(language("zh-Hant", "汉字") == "zh-Hant")
        #expect(language("ko", "한글") == "ko")
        #expect(language("zh-Hans", "汉字") == nil)
        #expect(language("ja", "かな") == nil)
    }

    @MainActor
    @Test("Two locales are cached apart")
    func cacheDistinguishesLocale() {
        let japanese = RenderProbe.content("placeholder", locale: .init(identifier: "ja"))
        let chinese = RenderProbe.content("placeholder", locale: .init(identifier: "zh-Hans"))

        let fromJapanese = japanese.cachedBodyText("汉字", theme: .default)
        let fromChinese = chinese.cachedBodyText("汉字", theme: .default)

        // Two contents, two locales, one shared cache: the entries must not be
        // the same one, and the difference has to survive as far as the glyphs.
        #expect(fromJapanese !== fromChinese)
        #expect(glyphs(of: fromJapanese) != glyphs(of: fromChinese))
    }

    @MainActor
    @Test("Scripts that name their own language ignore the locale")
    func scriptsOverrideTheLocale() {
        // Kana, hangul, Arabic and Hebrew identify their language on their own;
        // only Han is ambiguous enough to need the locale.
        let content = RenderProbe.content("placeholder", locale: .init(identifier: "en_US"))
        let rendered = content.cachedBodyText("かな 한글 العربية עברית plain", theme: .default)

        // Korean, Arabic and Hebrew still shape differently with the attribute,
        // so they keep it. Kana resolves to a Japanese font instead.
        #expect(RenderProbe.language(at: "한", in: rendered) == "ko")
        #expect(RenderProbe.language(at: "ع", in: rendered) == "ar")
        #expect(RenderProbe.language(at: "ע", in: rendered) == "he")
        #expect(RenderProbe.language(at: "plain", in: rendered) == nil)
        #expect(RenderProbe.font(at: "か", in: rendered) != RenderProbe.font(at: "plain", in: rendered))
    }

    @MainActor
    @Test("Han inside a kana word is read as Japanese")
    func hanInAKanaWordReadsAsJapanese() {
        // 日本語 is Han, but the token it sits in carries kana, so the whole word
        // is Japanese even when the reader's locale is Chinese.
        let content = RenderProbe.content("placeholder", locale: .init(identifier: "zh-Hans"))
        let rendered = content.cachedBodyText("日本語かな 中文", theme: .default)

        #expect(RenderProbe.font(at: "日", in: rendered) != RenderProbe.font(at: "中", in: rendered))
    }

    @MainActor
    @Test("Latin-only text carries no language attribute")
    func latinTextCarriesNoLanguage() {
        let content = RenderProbe.content("placeholder")
        let rendered = content.cachedBodyText("Plain english sentence.", theme: .default)

        var found = false
        rendered.enumerateAttribute(
            .coreTextLanguage,
            in: NSRange(location: 0, length: rendered.length),
            options: []
        ) { value, _, _ in
            if value != nil { found = true }
        }
        #expect(!found)
    }

    @MainActor
    @Test("Changing the theme on a live view re-renders its text")
    func themeChangeRerendersTheDocument() {
        let markdown = "一段中文 paragraph with text."
        let view = MarkdownTextView()
        view.theme = themeWithBodyFont(size: 12)
        RenderProbe.show(markdown, in: view, theme: view.theme)
        let before = RenderProbe.font(at: "paragraph", in: view.textLabelView.attributedText)

        view.theme = themeWithBodyFont(size: 28)
        RenderProbe.layout(view)
        let after = RenderProbe.font(at: "paragraph", in: view.textLabelView.attributedText)

        #expect(before?.pointSize == 12)
        #expect(after?.pointSize == 28)
    }

    @MainActor
    @Test("A theme change grows the laid out document")
    func themeChangeChangesMeasuredHeight() {
        let markdown = String(repeating: "一段中文 paragraph with text. ", count: 8)
        let view = MarkdownTextView()
        view.theme = themeWithBodyFont(size: 12)
        RenderProbe.show(markdown, in: view, width: 320, theme: view.theme)
        let small = view.boundingSize(for: 320).height

        view.theme = themeWithBodyFont(size: 28)
        RenderProbe.layout(view)
        let large = view.boundingSize(for: 320).height

        #expect(large > small)
    }

    @MainActor
    @Test("Inline styles keep their own fonts and colors, not the body's")
    func inlineStylesSurviveTheBodyCache() {
        // Bold, code and links are built around the cached body text; a cache
        // that handed back a shared mutable instance would let one of them
        // repaint the plain text around it.
        let view = RenderProbe.view("plain **bold** `code` [link](https://example.com) plain again")
        let text = view.textLabelView.attributedText

        let plain = RenderProbe.font(at: "plain again", in: text)
        let bold = RenderProbe.font(at: "bold", in: text)
        let code = RenderProbe.font(at: "code", in: text)

        #expect(plain != nil)
        #expect(bold != plain)
        #expect(code != plain)
        #expect(text.attribute(
            .link,
            at: (text.string as NSString).range(of: "link").location,
            effectiveRange: nil
        ) != nil)
        // The plain run must not have picked up the link's color.
        #expect(RenderProbe.color(at: "plain again", in: text) == MarkdownTheme.default.colors.body)
    }

    @MainActor
    @Test("Two contents share one rendering of the same text")
    func renderedTextIsSharedBetweenContents() {
        // Streaming builds a new content per token, so a cache that does not
        // reach across instances never gets a second lookup. Asserting the
        // shared instance is what keeps that from quietly reverting.
        let first = RenderProbe.content("placeholder")
        let second = RenderProbe.content("placeholder")
        let theme = MarkdownTheme.default

        let fromFirst = first.cachedBodyText("共享的一段文字 shared run", theme: theme)
        let fromSecond = second.cachedBodyText("共享的一段文字 shared run", theme: theme)

        #expect(fromFirst === fromSecond)
    }

    @MainActor
    @Test("A shared entry still belongs to its own theme")
    func sharedCacheKeepsThemesApart() {
        let first = RenderProbe.content("placeholder")
        let second = RenderProbe.content("placeholder")

        let small = first.cachedBodyText("同一段文字 same text", theme: themeWithBodyFont(size: 12))
        let large = second.cachedBodyText("同一段文字 same text", theme: themeWithBodyFont(size: 24))

        #expect((small.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont)?.pointSize == 12)
        #expect((large.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont)?.pointSize == 24)
    }

    @MainActor
    @Test("Bold Han text is bold, not merely a fallback font")
    func boldHanTextKeepsItsWeight() {
        // Bold is applied by walking the rendered runs and replacing any font
        // that is still the body font. A cached fragment that already carries a
        // resolved fallback font is no longer equal to the body font, so this
        // asserts the outcome — bold Han differs from plain Han — rather than
        // the branch that produces it.
        let view = RenderProbe.view("普通中文 and **加粗中文** together.")
        let text = view.textLabelView.attributedText

        let plain = RenderProbe.font(at: "普通中文", in: text)
        let bold = RenderProbe.font(at: "加粗中文", in: text)

        #expect(plain != nil)
        #expect(bold != nil)
        #expect(bold != plain)
    }

    @MainActor
    @Test("Two colors that resolve alike are still cached apart")
    func colorsThatResolveAlikeAreCachedApart() {
        // A dynamic color repaints itself when the appearance changes; a literal
        // one with the same components today does not. A cache that keys on the
        // resolved components hands the dynamic caller the frozen color and the
        // text stops following dark mode.
        let dynamic = MarkdownTheme.default.colors.body
        let literal = frozenCopy(of: dynamic)
        let content = RenderProbe.content("placeholder")

        var dynamicTheme = MarkdownTheme.default
        dynamicTheme.colors.body = dynamic
        var literalTheme = MarkdownTheme.default
        literalTheme.colors.body = literal

        let fromDynamic = content.cachedBodyText("同一段文字", theme: dynamicTheme)
        let fromLiteral = content.cachedBodyText("同一段文字", theme: literalTheme)

        #expect(
            fromDynamic.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor === dynamic
        )
        #expect(
            fromLiteral.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor === literal
        )
    }

    /// A static color with the same components `color` resolves to right now.
    @MainActor
    private func frozenCopy(of color: PlatformColor) -> PlatformColor {
        #if canImport(UIKit)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #elseif canImport(AppKit)
            guard let resolved = color.usingColorSpace(.deviceRGB) else { return .black }
            return NSColor(
                deviceRed: resolved.redComponent,
                green: resolved.greenComponent,
                blue: resolved.blueComponent,
                alpha: resolved.alphaComponent
            )
        #endif
    }

    @MainActor
    @Test("A repeated word renders the same way at every occurrence")
    func repeatedWordsRenderConsistently() {
        // The obvious way to make the cache cheaper is to key it more loosely.
        // The same word in a heading, in bold and in body text must still come
        // out with the styling of the place it sits in.
        let view = RenderProbe.view("""
        # word

        word and **word** and `word`.
        """)
        let text = view.textLabelView.attributedText
        let nsText = text.string as NSString

        var fonts: [PlatformFont] = []
        var searchStart = 0
        while searchStart < nsText.length {
            let range = nsText.range(
                of: "word",
                options: [],
                range: NSRange(location: searchStart, length: nsText.length - searchStart)
            )
            guard range.location != NSNotFound else { break }
            if let font = text.attribute(.font, at: range.location, effectiveRange: nil) as? PlatformFont {
                fonts.append(font)
            }
            searchStart = range.upperBound
        }

        #expect(fonts.count == 4)
        // Heading, body, bold and code: at least three distinct fonts among four
        // identical words proves the cache is not keyed on the word alone.
        #expect(Set(fonts.map { "\($0.fontName) \($0.pointSize)" }).count >= 3)
    }
}
