// Deliberately not `@testable`: half of what is under test here is that a
// client module — one that only ever sees the public surface — can subclass
// ``MarkdownTextView`` and override the decoration hook at all.
import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A subclass written the way a client writes one: it marks a name it knows
/// about, and it knows about it only after `rosterLoaded` says so.
@MainActor
private final class ChipTextView: MarkdownTextView {
    static let marker = NSAttributedString.Key("inlineDecorationTestMarker")

    var rosterLoaded = true

    override func decorate(inlineText text: NSAttributedString, theme _: MarkdownTheme) -> NSAttributedString {
        guard rosterLoaded else { return text }
        let range = (text.string as NSString).range(of: "@agent")
        guard range.location != NSNotFound else { return text }
        let decorated = NSMutableAttributedString(attributedString: text)
        decorated.addAttribute(Self.marker, value: true, range: range)
        return decorated
    }
}

@MainActor
private func markedRangeCount(in view: MarkdownTextView) -> Int {
    let text = view.textLabelView.attributedText
    var count = 0
    text.enumerateAttribute(
        ChipTextView.marker,
        in: NSRange(location: 0, length: text.length)
    ) { value, _, _ in
        if value != nil { count += 1 }
    }
    return count
}

struct MarkdownViewInlineDecorationTests {
    @MainActor
    @Test("A subclass decorates body text, and only body text")
    func decoratesBodyText() {
        let view = ChipTextView()
        view.frame = .init(x: 0, y: 0, width: 400, height: 200)

        // Three candidates, one decoration: the code span and the link
        // destination are their own inline nodes and never reach the hook.
        view.setMarkdown("hello @agent, not `@agent`, not [x](https://e.com/@agent)")

        #expect(markedRangeCount(in: view) == 1)
    }

    @MainActor
    @Test("The default view leaves text alone")
    func defaultViewDecoratesNothing() {
        let view = MarkdownTextView()
        view.frame = .init(x: 0, y: 0, width: 400, height: 200)
        view.setMarkdown("hello @agent")

        #expect(markedRangeCount(in: view) == 0)
    }

    @MainActor
    @Test("Invalidating rebuilds text the fragment cache would have reused")
    func invalidationRebuildsDecoratedText() {
        let view = ChipTextView()
        view.frame = .init(x: 0, y: 0, width: 400, height: 200)
        view.rosterLoaded = false
        view.setMarkdown("hello @agent")
        #expect(markedRangeCount(in: view) == 0)

        // The document has not changed, so nothing but the invalidation can
        // make the cached fragment give way.
        view.rosterLoaded = true
        view.invalidateInlineDecoration()

        #expect(markedRangeCount(in: view) == 1)
    }
}
