import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Shared probing for the tests that guard the rendering pipeline.
///
/// The pipeline caches and rebuilds a lot, and is about to cache and rebuild
/// differently. So these look at what a reader is left with — the text, the
/// attributes carrying its appearance, the views that were placed — and never
/// at how the builder arrived there.
enum RenderProbe {
    /// Attributes whose value means the same thing across two separate builds.
    static let valueAttributes: [NSAttributedString.Key] = [
        .font,
        .foregroundColor,
        .backgroundColor,
        .paragraphStyle,
        .link,
        .underlineStyle,
        .strikethroughStyle,
        .coreTextLanguage,
    ]

    /// Attributes holding an object that is a new instance on every build by
    /// design — a pooled view, an attachment, a drawing callback. Where they sit
    /// can be compared; what they are cannot.
    static let identityAttributes: [NSAttributedString.Key] = [
        .contextView,
        .litextAttachment,
        .litextLineDrawingAction,
        .blockquoteGroup,
    ]

    @MainActor
    static func content(
        _ markdown: String,
        theme: MarkdownTheme = .default,
        locale: Locale = .init(identifier: "en_US")
    ) -> MarkdownContent {
        .init(
            parserResult: MarkdownParser().parse(markdown),
            theme: theme,
            locale: locale
        )
    }

    /// A view showing `markdown`, sized and laid out at `width`.
    @MainActor
    static func view(
        _ markdown: String,
        width: CGFloat = 480,
        theme: MarkdownTheme = .default,
        locale: Locale = .init(identifier: "en_US")
    ) -> MarkdownTextView {
        let view = MarkdownTextView()
        view.theme = theme
        show(markdown, in: view, width: width, theme: theme, locale: locale)
        return view
    }

    /// Puts `markdown` into an existing view and returns the document it built.
    ///
    /// Reusing a view is the point of most of these tests: pooled code and table
    /// views, cached inline text and stashed layout all only misbehave on the
    /// second pass through the same view.
    @MainActor
    @discardableResult
    static func show(
        _ markdown: String,
        in view: MarkdownTextView,
        width: CGFloat = 480,
        theme: MarkdownTheme = .default,
        locale: Locale = .init(identifier: "en_US")
    ) -> NSAttributedString {
        view.setContentImmediately(content(markdown, theme: theme, locale: locale))
        view.frame = .init(
            x: 0,
            y: 0,
            width: width,
            height: view.boundingSize(for: width).height
        )
        layout(view)
        return view.textLabelView.attributedText
    }

    @MainActor
    static func layout(_ view: MarkdownTextView) {
        #if canImport(UIKit)
            view.setNeedsLayout()
            view.layoutIfNeeded()
        #elseif canImport(AppKit)
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
        #endif
    }

    /// One line per attribute run, plus the text itself.
    ///
    /// Comparing digests rather than the attributed strings themselves keeps a
    /// failure readable: the first differing line names the attribute, where it
    /// starts and what it became.
    @MainActor
    static func digest(_ text: NSAttributedString) -> [String] {
        var lines = ["string: \(text.string)"]
        let whole = NSRange(location: 0, length: text.length)
        for key in valueAttributes {
            text.enumerateAttribute(key, in: whole, options: []) { value, range, _ in
                guard let value else { return }
                lines.append("\(key.rawValue)@\(range.location)+\(range.length) = \(describe(value))")
            }
        }
        for key in identityAttributes {
            text.enumerateAttribute(key, in: whole, options: []) { value, range, _ in
                guard value != nil else { return }
                lines.append("\(key.rawValue)@\(range.location)+\(range.length) present")
            }
        }
        return lines
    }

    /// The first line on which two digests part ways, for a failure message.
    static func firstDifference(_ lhs: [String], _ rhs: [String]) -> String {
        for (index, line) in lhs.enumerated() {
            guard index < rhs.count else { return "missing: \(line)" }
            if line != rhs[index] { return "\(line)\n  vs\n\(rhs[index])" }
        }
        if rhs.count > lhs.count { return "extra: \(rhs[lhs.count])" }
        return "identical"
    }

    /// Every attachment's stand-in text, in document order.
    ///
    /// A drawn block — a list marker, a code block, a table — is one replacement
    /// character in the text, and the attachment is the only place the thing it
    /// stands for can be read back.
    @MainActor
    static func attachmentTexts(in text: NSAttributedString) -> [String] {
        var result: [String] = []
        text.enumerateAttribute(
            .litextAttachment,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, _, _ in
            guard let attachment = value as? TextLabel.Attachment else { return }
            result.append(attachment.attributedStringRepresentation().string)
        }
        return result
    }

    /// The paragraph style in force at the first occurrence of `needle`.
    @MainActor
    static func paragraphStyle(at needle: String, in text: NSAttributedString) -> NSParagraphStyle? {
        let range = (text.string as NSString).range(of: needle)
        guard range.location != NSNotFound else { return nil }
        return text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
    }

    /// The font in force at the first occurrence of `needle`.
    @MainActor
    static func font(at needle: String, in text: NSAttributedString) -> PlatformFont? {
        let range = (text.string as NSString).range(of: needle)
        guard range.location != NSNotFound else { return nil }
        return text.attribute(.font, at: range.location, effectiveRange: nil) as? PlatformFont
    }

    /// The foreground color in force at the first occurrence of `needle`.
    @MainActor
    static func color(at needle: String, in text: NSAttributedString) -> PlatformColor? {
        let range = (text.string as NSString).range(of: needle)
        guard range.location != NSNotFound else { return nil }
        return text.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? PlatformColor
    }

    /// The CoreText language in force at the first occurrence of `needle`.
    @MainActor
    static func language(at needle: String, in text: NSAttributedString) -> String? {
        let range = (text.string as NSString).range(of: needle)
        guard range.location != NSNotFound else { return nil }
        return text.attribute(.coreTextLanguage, at: range.location, effectiveRange: nil) as? String
    }

    private static func describe(_ value: Any) -> String {
        if let font = value as? PlatformFont {
            return "\(font.fontName) \(String(format: "%.2f", font.pointSize))"
        }
        if let style = value as? NSParagraphStyle {
            // Spelled out field by field: `description` carries defaults that
            // differ between platforms and would make the digest untransferable.
            let metrics = [
                style.firstLineHeadIndent,
                style.headIndent,
                style.tailIndent,
                style.paragraphSpacing,
                style.paragraphSpacingBefore,
                style.lineSpacing,
                style.minimumLineHeight,
            ].map { String(format: "%.2f", $0) }.joined(separator: ",")
            return "\(metrics) align=\(style.alignment.rawValue)"
        }
        return String(describing: value)
    }
}

/// A document exercising every block kind, in a mix of scripts.
///
/// Perf work on the builder tends to break the blocks it did not have in mind,
/// so the tests that compare whole documents all run against this one.
enum RenderProbeDocument {
    static let everything = """
    # 标题 Heading One

    一段中文 paragraph with **bold**, *emphasis*, `inline code`, \
    [a link](https://example.com) and ~~strikethrough~~ in it.

    ## 二级标题

    - 第一项 bullet item
    - 第二项 bullet item
      - 嵌套 nested item

    1. 第一 numbered
    2. 第二 numbered

    - [ ] 未完成 task
    - [x] 已完成 task

    > 引用第一行 quoted line
    > 引用第二行 quoted line

    ---

    ```swift
    let answer = 42
    print(answer)
    ```

    | 列 A | 列 B |
    | :-- | --: |
    | 1 | 中文单元格 |
    | 2 | another cell |

    最后一段 trailing paragraph.
    """
}
