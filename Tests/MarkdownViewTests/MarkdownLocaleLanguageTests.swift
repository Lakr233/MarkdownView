import CoreText
import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The reader's locale reaches Han text as a language attribute, and the
/// locale comes spelled every way Foundation spells it: `zh_CN`, `zh-Hans-CN`,
/// `zh_TW`, `zh_HK`. Those spellings are folded into one per way of drawing
/// Han text, so the attribute can be dropped wherever it no longer changes
/// the result.
///
/// The folding must never change what is drawn. These compare the shapes
/// CoreText produces — glyph, font and advance for every character — against
/// the raw spelling the locale arrived in.
struct MarkdownLocaleLanguageTests {
    private struct Shape: Equatable {
        var glyphs: [CGGlyph] = []
        var fonts: [String] = []
        var advances: [CGFloat] = []
    }

    /// Six thousand ideographs from the start of the unified block, enough to
    /// cover every character a Simplified, Traditional or Hong Kong font
    /// draws differently in common text.
    private static let han: String = {
        var scalars = String.UnicodeScalarView()
        for value in 0x4E00 ..< 0x4E00 + 6000 {
            scalars.append(Unicode.Scalar(value)!)
        }
        return String(scalars)
    }()

    @MainActor
    private func shape(of text: NSAttributedString) -> Shape {
        var result = Shape()
        let line = CTLineCreateWithAttributedString(text)
        for run in CTLineGetGlyphRuns(line) as NSArray {
            let run = run as! CTRun
            let count = CTRunGetGlyphCount(run)
            let range = CFRange(location: 0, length: count)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetGlyphs(run, range, &glyphs)
            CTRunGetAdvances(run, range, &advances)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let font = attributes[kCTFontAttributeName] as! CTFont
            let name = CTFontCopyPostScriptName(font) as String
            result.glyphs += glyphs
            result.fonts += Array(repeating: name, count: count)
            result.advances += advances.map(\.width)
        }
        return result
    }

    /// Han text as this package rendered it before the locale was folded: the
    /// locale's identifier, verbatim, as the language of every ideograph, and
    /// left in place after the font was resolved.
    @MainActor
    private func shapeWithRawLanguage(_ identifier: String) -> Shape {
        let theme = MarkdownTheme.default
        let text = NSMutableAttributedString(
            string: Self.han,
            attributes: [
                .font: theme.fonts.body,
                .foregroundColor: theme.colors.body,
                .coreTextLanguage: identifier,
            ],
        )
        text.fixAttributes(in: NSRange(location: 0, length: text.length))
        return shape(of: text)
    }

    @MainActor
    private func rendered(_ text: String, locale identifier: String) -> NSAttributedString {
        RenderProbe.content("placeholder", locale: .init(identifier: identifier))
            .cachedBodyText(text, theme: .default)
    }

    @MainActor
    private func languages(in text: NSAttributedString) -> Set<String> {
        var result = Set<String>()
        text.enumerateAttribute(
            .coreTextLanguage,
            in: NSRange(location: 0, length: text.length),
            options: [],
        ) { value, _, _ in
            if let language = value as? String {
                result.insert(language)
            }
        }
        return result
    }

    @MainActor
    @Test(
        arguments: [
            ("zh", "zh-Hans"),
            ("zh_CN", "zh-Hans"),
            ("zh_SG", "zh-Hans"),
            ("zh-Hans", "zh-Hans"),
            ("zh-Hans-CN", "zh-Hans"),
            ("zh-Hans_HK", "zh-Hans"),
            ("zh_CN@calendar=chinese", "zh-Hans"),
            ("zh-Hant", "zh-Hant"),
            ("zh_TW", "zh-Hant"),
            ("zh-Hant-TW", "zh-Hant"),
            ("zh-Hant_US", "zh-Hant-US"),
            ("zh_HK", "zh-Hant-HK"),
            ("zh_MO", "zh-Hant-MO"),
            ("ja", "ja"),
            ("ja_JP", "ja"),
            ("ko", "ko"),
            ("ko_KR", "ko"),
            ("en_US", "zh-Hans"),
            // Identifiers that merely start with "ja" or "ko" are other
            // languages, and fall back like any other language does.
            ("jam", "zh-Hans"),
            ("kok", "zh-Hans"),
            ("", "zh-Hans"),
        ],
    )
    func `A locale is folded by its language, script and region`(identifier: String, expected: String) {
        #expect(MarkdownContentLocale.normalizedLanguage(Locale(identifier: identifier).language) == expected)
    }

    @MainActor
    @Test(
        arguments: ["zh", "zh_CN", "zh_SG", "zh-Hans-CN", "zh-Hans"],
    )
    func `Simplified Chinese leaves no language attribute, however the locale is spelled`(identifier: String) {
        let text = rendered("简体中文 mixed 汉字。", locale: identifier)
        #expect(text.string == "简体中文 mixed 汉字。")
        #expect(languages(in: text).isEmpty)
    }

    @MainActor
    @Test
    func `Traditional Chinese keeps its attribute, with its region`() {
        // Dropping it would change the glyph of four in ten ideographs, so it
        // stays; the region stays with it, because Hong Kong and Macau have
        // fonts of their own.
        #expect(languages(in: rendered("繁體中文", locale: "zh-Hant")) == ["zh-Hant"])
        #expect(languages(in: rendered("繁體中文", locale: "zh_TW")) == ["zh-Hant"])
        #expect(languages(in: rendered("繁體中文", locale: "zh_HK")) == ["zh-Hant-HK"])
        #expect(languages(in: rendered("繁體中文", locale: "zh_MO")) == ["zh-Hant-MO"])
    }

    @MainActor
    @Test(
        arguments: [
            "zh", "zh_CN", "zh_SG", "zh-Hans-CN", "zh-Hans_HK",
            "zh-Hant", "zh_TW", "zh-Hant-TW", "zh-Hant_US", "zh_HK", "zh_MO",
        ],
    )
    func `Folding the locale draws every ideograph exactly as the raw locale did`(identifier: String) {
        let before = shapeWithRawLanguage(identifier)
        let after = shape(of: rendered(Self.han, locale: identifier))

        #expect(before.glyphs.count == Self.han.unicodeScalars.count)
        #expect(after.glyphs == before.glyphs)
        #expect(after.fonts == before.fonts)
        #expect(after.advances == before.advances)
    }

    @MainActor
    @Test
    func `Simplified and Traditional readers never see each other's glyphs`() {
        // Rendered alternately, so a cache keyed on the folded language rather
        // than the locale would hand one reader the other's text.
        let simplified = shape(of: rendered(Self.han, locale: "zh_CN"))
        let taiwan = shape(of: rendered(Self.han, locale: "zh_TW"))
        let hongKong = shape(of: rendered(Self.han, locale: "zh_HK"))
        let simplifiedAgain = shape(of: rendered(Self.han, locale: "zh_CN"))
        let taiwanAgain = shape(of: rendered(Self.han, locale: "zh_TW"))

        #expect(simplified.glyphs != taiwan.glyphs)
        #expect(simplified.glyphs != hongKong.glyphs)
        #expect(taiwan.glyphs != hongKong.glyphs, "Hong Kong is drawn in its own font, not Taiwan's")
        #expect(simplifiedAgain == simplified)
        #expect(taiwanAgain == taiwan)
        #expect(simplified == shape(of: rendered(Self.han, locale: "zh-Hans")))
        #expect(taiwan == shape(of: rendered(Self.han, locale: "zh-Hant")))
    }

    @MainActor
    @Test
    func `A document under zh_CN is the document under zh-Hans, attribute for attribute`() {
        let spelled = RenderProbe.show(
            RenderProbeDocument.everything,
            in: MarkdownTextView(),
            locale: Locale(identifier: "zh_CN"),
        )
        let canonical = RenderProbe.show(
            RenderProbeDocument.everything,
            in: MarkdownTextView(),
            locale: Locale(identifier: "zh-Hans"),
        )

        let spelledDigest = RenderProbe.digest(spelled)
        let canonicalDigest = RenderProbe.digest(canonical)
        #expect(
            spelledDigest == canonicalDigest,
            "\(RenderProbe.firstDifference(spelledDigest, canonicalDigest))",
        )
        #expect(languages(in: spelled).isEmpty)
    }

    @MainActor
    @Test
    func `Copying a document reads the same text under every Chinese locale`() {
        func copied(_ identifier: String) -> String? {
            let view = MarkdownTextView()
            RenderProbe.show(
                RenderProbeDocument.everything,
                in: view,
                locale: Locale(identifier: identifier),
            )
            view.textLabelView.selectAll()
            return view.textLabelView.selectedPlainText()
        }

        let english = copied("en_US")
        #expect(english?.contains("最后一段 trailing paragraph.") == true)
        #expect(english?.contains("中文单元格") == true)
        for identifier in ["zh_CN", "zh-Hans", "zh_TW", "zh_HK", "ja_JP"] {
            #expect(copied(identifier) == english, "copied text differs under \(identifier)")
        }
    }
}
