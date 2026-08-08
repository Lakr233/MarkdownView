import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The cheapest way to speed up streaming is to stop rebuilding blocks that did
/// not change, keyed on the block node. Block nodes are `Hashable`, so two
/// identical blocks in one document are the same key — and several things a
/// block carries must stay distinct anyway: its own quoting bar, its own code
/// view, its own table, its own position in a numbered list.
///
/// These are the cases where sharing by block value would be wrong.
struct MarkdownBlockIdentityTests {
    @MainActor
    private func blockquoteGroups(in text: NSAttributedString) -> [BlockquoteGroup] {
        var groups: [BlockquoteGroup] = []
        text.enumerateAttribute(
            .blockquoteGroup,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, _, _ in
            guard let group = value as? BlockquoteGroup else { return }
            if !groups.contains(where: { $0 === group }) { groups.append(group) }
        }
        return groups
    }

    @MainActor
    @Test("Two identical quotes are two quotes, not one")
    func identicalQuotesKeepSeparateGroups() {
        let view = RenderProbe.view("""
        > 完全相同的引用 identical quote

        Between the two quotes.

        > 完全相同的引用 identical quote
        """)

        let groups = blockquoteGroups(in: view.textLabelView.attributedText)
        #expect(groups.count == 2)
        #expect(groups[0] !== groups[1])
        // One bar each: a shared group would union the two spans and paint a
        // single bar straight through the paragraph between them.
        #expect(view.blockquoteBars.count == 2)
    }

    @MainActor
    @Test("Adjacent quote lines stay one quote")
    func adjacentQuoteLinesShareOneGroup() {
        let view = RenderProbe.view("""
        > 第一行 first line
        > 第二行 second line
        > 第三行 third line
        """)

        #expect(blockquoteGroups(in: view.textLabelView.attributedText).count == 1)
        #expect(view.blockquoteBars.count == 1)
    }

    @MainActor
    @Test("Two identical code blocks get two code views")
    func identicalCodeBlocksGetSeparateViews() {
        let view = RenderProbe.view("""
        ```swift
        let answer = 42
        ```

        Between the two blocks.

        ```swift
        let answer = 42
        ```
        """)

        let codeViews = view.contextViews.compactMap { $0 as? CodeView }
        #expect(codeViews.count == 2)
        #expect(codeViews[0] !== codeViews[1])
        // Both must be placed: a single view cannot sit in two places.
        #expect(codeViews.allSatisfy { $0.superview === view && !$0.isHidden })
        #expect(codeViews[0].frame.minY != codeViews[1].frame.minY)
    }

    @MainActor
    @Test("Two identical tables get two table views")
    func identicalTablesGetSeparateViews() {
        let view = RenderProbe.view("""
        | A | B |
        | - | - |
        | 1 | 2 |

        Between the two tables.

        | A | B |
        | - | - |
        | 1 | 2 |
        """)

        let tableViews = view.contextViews.compactMap { $0 as? TableView }
        #expect(tableViews.count == 2)
        #expect(tableViews[0] !== tableViews[1])
        #expect(tableViews.allSatisfy { $0.superview === view && !$0.isHidden })
        #expect(tableViews[0].frame.minY != tableViews[1].frame.minY)
    }

    @MainActor
    @Test("A repeated paragraph appears once per occurrence")
    func repeatedParagraphsAllAppear() {
        let view = RenderProbe.view("""
        完全相同的一段 repeated paragraph.

        完全相同的一段 repeated paragraph.

        完全相同的一段 repeated paragraph.
        """)

        let text = view.textLabelView.attributedText.string as NSString
        var count = 0
        var cursor = 0
        while cursor < text.length {
            let range = text.range(
                of: "repeated paragraph.",
                options: [],
                range: NSRange(location: cursor, length: text.length - cursor)
            )
            guard range.location != NSNotFound else { break }
            count += 1
            cursor = range.upperBound
        }
        #expect(count == 3)
    }

    @MainActor
    @Test("A numbered list carries its start index into each marker")
    func numberedMarkersFollowTheStartIndex() {
        let view = RenderProbe.view("""
        5. 第五 five
        6. 第六 six
        7. 第七 seven
        """)

        let markers = RenderProbe.attachmentTexts(in: view.textLabelView.attributedText)
        #expect(markers == ["5. ", "6. ", "7. "])
    }

    @MainActor
    @Test("Identical list text at two depths gets two indents")
    func identicalItemsAtDifferentDepthsIndentDifferently() {
        let view = RenderProbe.view("""
        - 相同文字 same text outer
          - 相同文字 same text inner
        """)
        let text = view.textLabelView.attributedText

        let outer = RenderProbe.paragraphStyle(at: "same text outer", in: text)
        let inner = RenderProbe.paragraphStyle(at: "same text inner", in: text)

        #expect(outer?.headIndent == ListMarkerLayout.indent)
        #expect(inner?.headIndent == ListMarkerLayout.indent * 2)
        #expect(outer?.firstLineHeadIndent == outer?.headIndent)
        #expect(inner?.firstLineHeadIndent == inner?.headIndent)
    }

    @MainActor
    @Test("Bullet, task and numbered markers stand for their own markdown")
    func markersStandForTheirOwnMarkdown() {
        let view = RenderProbe.view("""
        - bullet one
        - bullet two

        1. numbered one

        - [ ] open task
        - [x] done task
        """)

        let markers = RenderProbe.attachmentTexts(in: view.textLabelView.attributedText)
        #expect(markers == ["- ", "- ", "1. ", "- [ ] ", "- [x] "])
    }

    @MainActor
    @Test("A nested bullet marker carries its nesting")
    func nestedBulletMarkersCarryDepth() {
        let view = RenderProbe.view("""
        - outer
          - inner
            - innermost
        """)

        #expect(RenderProbe.attachmentTexts(in: view.textLabelView.attributedText) == [
            "- ", "  - ", "    - ",
        ])
    }

    @MainActor
    @Test("Blocks keep document order")
    func blocksKeepDocumentOrder() {
        let view = RenderProbe.view("""
        first paragraph

        - a bullet

        second paragraph

        > a quote

        third paragraph
        """)
        let text = view.textLabelView.attributedText.string as NSString

        let first = text.range(of: "first paragraph").location
        let bullet = text.range(of: "a bullet").location
        let second = text.range(of: "second paragraph").location
        let quote = text.range(of: "a quote").location
        let third = text.range(of: "third paragraph").location

        #expect(first < bullet)
        #expect(bullet < second)
        #expect(second < quote)
        #expect(quote < third)
    }

    @MainActor
    @Test("A code block reserves exactly the height its view occupies")
    func codeBlockReservesItsViewHeight() {
        // The reserved height is read off the code view, so a cache that hands
        // back a block built against a different view would reserve the wrong
        // band and let the code paint over the paragraph below it.
        let view = RenderProbe.view("""
        Before.

        ```swift
        let a = 1
        let b = 2
        let c = 3
        ```

        After.
        """)

        let codeView = view.contextViews.compactMap { $0 as? CodeView }.first
        let text = view.textLabelView.attributedText
        var reserved: CGFloat?
        text.enumerateAttribute(
            .contextView,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, range, _ in
            guard value is CodeView else { return }
            reserved = (text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil)
                as? NSParagraphStyle)?.minimumLineHeight
        }

        #expect(codeView != nil)
        #expect(reserved == codeView?.intrinsicContentSize.height)
        #expect((reserved ?? 0) > 0)
    }

    @MainActor
    @Test("A table reserves exactly the height its view occupies")
    func tableReservesItsViewHeight() {
        let view = RenderProbe.view("""
        Before.

        | A | B |
        | - | - |
        | 1 | 2 |
        | 3 | 4 |

        After.
        """)

        let tableView = view.contextViews.compactMap { $0 as? TableView }.first
        let text = view.textLabelView.attributedText
        var reserved: CGFloat?
        text.enumerateAttribute(
            .contextView,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, range, _ in
            guard value is TableView else { return }
            reserved = (text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil)
                as? NSParagraphStyle)?.minimumLineHeight
        }

        #expect(tableView != nil)
        #expect(reserved == tableView?.intrinsicContentHeight)
        #expect((reserved ?? 0) > 0)
    }
}
