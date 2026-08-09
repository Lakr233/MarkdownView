@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The builder resolves fallback fonts one block at a time and caches the
/// result, rather than sweeping the finished document.
///
/// That trade is only sound because `fixAttributes` works a paragraph at a
/// time and every block ends with a newline, so a block never shares a
/// paragraph with its neighbour. These pin both halves: that the shortcut
/// reaches the same attributes as the sweep it replaced, and that the property
/// it depends on still holds.
struct MarkdownFontResolutionTests {
    /// Every block fragment ends with a newline.
    ///
    /// This is what keeps paragraph boundaries from crossing a fragment. If a
    /// block ever stops ending with one, fixing fragments separately stops
    /// matching fixing the document, and the failure would otherwise show up
    /// as a subtly wrong paragraph style somewhere far away.
    @MainActor
    @Test("Every block ends with a newline")
    func blocksEndWithNewline() {
        let view = RenderProbe.view(RenderProbeDocument.everything)
        let cache = view.blockFragmentCache
        var checked = 0
        for (index, node) in view.content.blocks.enumerated() {
            guard let fragment = cache.fragment(at: index, matching: node) else { continue }
            checked += 1
            #expect(
                fragment.string.hasSuffix("\n"),
                "block \(index) ends with \(fragment.string.suffix(8).debugDescription)"
            )
        }
        #expect(checked > 0)
    }

    /// Fixing each block reaches the same document as fixing the whole thing.
    ///
    /// Compared through the digest rather than `isEqual`, so a failure names
    /// the attribute and the offset instead of saying two long strings differ.
    @MainActor
    @Test("Per-block font resolution matches a whole-document sweep")
    func matchesWholeDocumentSweep() {
        let built = RenderProbe.show(RenderProbeDocument.everything, in: MarkdownTextView())

        let swept = built.mutableCopy() as! NSMutableAttributedString
        swept.fixAttributes(in: NSRange(location: 0, length: swept.length))

        let before = RenderProbe.digest(built)
        let after = RenderProbe.digest(swept)
        #expect(before == after, "\(RenderProbe.firstDifference(before, after))")
    }

    /// The same, for a document whose scripts the body font does not cover.
    ///
    /// CJK and emoji are the runs that actually need a substitute, so they are
    /// where a missed resolution would show — as a fallback chosen by CoreText
    /// during framesetting instead of one recorded in the document.
    @MainActor
    @Test("Scripts needing a substitute font resolve to a real font", arguments: [
        "中文段落 with English mixed in.",
        "日本語の段落です。",
        "한국어 문단입니다.",
        "emoji 🎉 in a paragraph 🚀",
        "# 标题里的中文 heading",
        "> 引用里的中文 quote",
        "- 列表里的中文 bullet",
    ])
    func substituteFontsAreResolved(_ markdown: String) {
        let text = RenderProbe.show(markdown, in: MarkdownTextView())
        let swept = text.mutableCopy() as! NSMutableAttributedString
        swept.fixAttributes(in: NSRange(location: 0, length: swept.length))

        #expect(
            RenderProbe.digest(text) == RenderProbe.digest(swept),
            "\(RenderProbe.firstDifference(RenderProbe.digest(text), RenderProbe.digest(swept)))"
        )
    }

    /// A block served from the cache carries its resolved fonts with it.
    ///
    /// The whole point of resolving per block is that a streamed update pays
    /// only for what changed. If a reused fragment came back unresolved, the
    /// document would still render correctly — CoreText would resolve it again
    /// while framesetting — and the cost this removes would silently return.
    @MainActor
    @Test("A reused block keeps its resolved fonts")
    func reusedBlocksKeepResolvedFonts() {
        let markdown = """
        中文第一段 stays put.

        中文第二段 also stays.
        """
        let view = RenderProbe.view(markdown)
        RenderProbe.show(markdown + "\n\n新的一段 arrives.", in: view)

        let text = view.textLabelView.attributedText
        let swept = text.mutableCopy() as! NSMutableAttributedString
        swept.fixAttributes(in: NSRange(location: 0, length: swept.length))
        #expect(
            RenderProbe.digest(text) == RenderProbe.digest(swept),
            "\(RenderProbe.firstDifference(RenderProbe.digest(text), RenderProbe.digest(swept)))"
        )
    }
}
