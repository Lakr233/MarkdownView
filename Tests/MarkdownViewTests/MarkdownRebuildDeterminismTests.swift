import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Every content change rebuilds the whole document today. Anything that makes
/// that cheaper — caching a block, reusing an inline run, skipping work that
/// looks unchanged — is only safe if the document it produces is the one a
/// full rebuild would have produced.
///
/// These pin that down: same input, same document, no matter how many times or
/// through which view it was built.
struct MarkdownRebuildDeterminismTests {
    /// The first build of a document warms what the later ones reuse: a pooled
    /// code view has no width yet, a table has never measured its columns, and
    /// the heights they reserve in the text differ until they have. Comparisons
    /// start from the second build.
    @MainActor
    private func warmedView(_ markdown: String, width: CGFloat = 480) -> MarkdownTextView {
        let view = RenderProbe.view(markdown, width: width)
        RenderProbe.show(markdown, in: view, width: width)
        return view
    }

    @MainActor
    @Test("Rebuilding the same content twice yields the same document")
    func rebuildingIsIdempotent() {
        let view = warmedView(RenderProbeDocument.everything)
        let first = RenderProbe.digest(view.textLabelView.attributedText)

        let second = RenderProbe.digest(
            RenderProbe.show(RenderProbeDocument.everything, in: view)
        )

        #expect(first == second, "\(RenderProbe.firstDifference(first, second))")
    }

    @MainActor
    @Test("A rebuild from a fresh content object matches a reused one")
    func freshContentMatchesReusedContent() {
        // Streaming callers build a new `MarkdownContent` per update, so the
        // per-content inline cache is empty every time; a one-shot caller reuses
        // one. Both have to render the same thing.
        let view = warmedView(RenderProbeDocument.everything)
        let reused = RenderProbe.content(RenderProbeDocument.everything)

        view.setContentImmediately(reused)
        _ = view.boundingSize(for: 480)
        let firstPass = RenderProbe.digest(view.textLabelView.attributedText)

        view.setContentImmediately(reused)
        _ = view.boundingSize(for: 480)
        let secondPass = RenderProbe.digest(view.textLabelView.attributedText)

        let fresh = RenderProbe.digest(
            RenderProbe.show(RenderProbeDocument.everything, in: view)
        )

        #expect(firstPass == secondPass, "\(RenderProbe.firstDifference(firstPass, secondPass))")
        #expect(secondPass == fresh, "\(RenderProbe.firstDifference(secondPass, fresh))")
    }

    @MainActor
    @Test("Two views with separate pools build the same document")
    func separateViewsAgree() {
        let left = warmedView(RenderProbeDocument.everything)
        let right = warmedView(RenderProbeDocument.everything)

        let leftDigest = RenderProbe.digest(left.textLabelView.attributedText)
        let rightDigest = RenderProbe.digest(right.textLabelView.attributedText)

        #expect(leftDigest == rightDigest, "\(RenderProbe.firstDifference(leftDigest, rightDigest))")
    }

    @MainActor
    @Test("A streamed document ends where a one-shot document does")
    func streamingConvergesOnTheOneShotDocument() {
        let markdown = RenderProbeDocument.everything
        let characters = Array(markdown)
        let step = max(1, characters.count / 24)

        let streamed = MarkdownTextView()
        var cursor = 0
        while cursor < characters.count {
            cursor = min(characters.count, cursor + step)
            RenderProbe.show(String(characters[0 ..< cursor]), in: streamed)
        }
        // The last prefix is the whole document, but the pooled views reached it
        // through every intermediate state; settle once more so the comparison is
        // against a fully applied layout.
        RenderProbe.show(markdown, in: streamed)

        let oneShot = warmedView(markdown)

        let streamedDigest = RenderProbe.digest(streamed.textLabelView.attributedText)
        let oneShotDigest = RenderProbe.digest(oneShot.textLabelView.attributedText)

        #expect(
            streamedDigest == oneShotDigest,
            "\(RenderProbe.firstDifference(streamedDigest, oneShotDigest))"
        )
        #expect(streamed.boundingSize(for: 480).height == oneShot.boundingSize(for: 480).height)
    }

    @MainActor
    @Test("Repeated rebuilds neither accumulate nor drop context views")
    func rebuildsKeepContextViewCountStable() {
        let markdown = RenderProbeDocument.everything
        let view = warmedView(markdown)

        let codeViews = view.contextViews.filter { $0 is CodeView }.count
        let tableViews = view.contextViews.filter { $0 is TableView }.count
        #expect(codeViews == 1)
        #expect(tableViews == 1)

        for _ in 0 ..< 5 {
            RenderProbe.show(markdown, in: view)
        }

        #expect(view.contextViews.count == codeViews + tableViews)
        #expect(view.contextViews.filter { $0 is CodeView }.count == codeViews)
        #expect(view.contextViews.filter { $0 is TableView }.count == tableViews)
        // Anything the builder stopped using has to leave the hierarchy too,
        // otherwise a stale code view keeps painting over the text.
        #expect(view.subviews.filter { $0 is CodeView }.count == codeViews)
        #expect(view.subviews.filter { $0 is TableView }.count == tableViews)
    }

    @MainActor
    @Test("Rebuilding reuses the pooled context views rather than new ones")
    func rebuildsReuseThePooledViews() {
        let markdown = RenderProbeDocument.everything
        let view = warmedView(markdown)

        let firstCode = view.contextViews.compactMap { $0 as? CodeView }
        let firstTable = view.contextViews.compactMap { $0 as? TableView }

        RenderProbe.show(markdown, in: view)

        let secondCode = view.contextViews.compactMap { $0 as? CodeView }
        let secondTable = view.contextViews.compactMap { $0 as? TableView }

        #expect(firstCode.count == secondCode.count)
        #expect(firstTable.count == secondTable.count)
        #expect(zip(firstCode, secondCode).allSatisfy { $0 === $1 })
        #expect(zip(firstTable, secondTable).allSatisfy { $0 === $1 })
    }

    @MainActor
    @Test("Emptying a view releases everything it was showing")
    func resetReleasesContextViews() {
        let view = warmedView(RenderProbeDocument.everything)
        #expect(!view.contextViews.isEmpty)

        view.reset()
        RenderProbe.layout(view)

        #expect(view.contextViews.isEmpty)
        #expect(view.textLabelView.attributedText.length == 0)
        #expect(view.subviews.filter { $0 is CodeView || $0 is TableView }.isEmpty)
    }

    @MainActor
    @Test("A document shrinking back to a prefix matches building that prefix")
    func shrinkingMatchesBuildingThePrefix() {
        // Editing and regeneration both walk content backwards, which is where a
        // cache keyed on "what changed" is easiest to get wrong.
        let prefix = """
        # 标题

        一段中文 paragraph.

        ```swift
        let answer = 42
        ```
        """
        let longer = prefix + """


        | A | B |
        | - | - |
        | 1 | 2 |

        Trailing.
        """

        let view = warmedView(longer)
        RenderProbe.show(prefix, in: view)
        let shrunk = RenderProbe.digest(view.textLabelView.attributedText)

        let direct = RenderProbe.digest(warmedView(prefix).textLabelView.attributedText)

        #expect(shrunk == direct, "\(RenderProbe.firstDifference(shrunk, direct))")
        #expect(view.contextViews.filter { $0 is TableView }.isEmpty)
    }

    @MainActor
    @Test("Layout width does not leak into the built document")
    func documentDoesNotDependOnWidth() {
        // Only line breaking may depend on the width. The attributed string the
        // builder produces must not, or a cache keyed on content alone would be
        // wrong the moment the window is resized.
        let wide = warmedView(RenderProbeDocument.everything, width: 900)
        let narrow = warmedView(RenderProbeDocument.everything, width: 320)

        let wideText = wide.textLabelView.attributedText.string
        let narrowText = narrow.textLabelView.attributedText.string

        #expect(wideText == narrowText)
        #expect(wide.boundingSize(for: 900).height < narrow.boundingSize(for: 320).height)
    }
}
