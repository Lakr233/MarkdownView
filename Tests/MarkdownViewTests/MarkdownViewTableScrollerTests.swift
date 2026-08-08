import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    struct MarkdownViewTableScrollerTests {
        private static let markdown = """
        | Left aligned | Centered | Right aligned |
        | :-- | :-: | --: |
        | short | mid | 1 |
        | a considerably longer cell that has to wrap | **bold** and code | 1145141919810 |
        | 中文单元格内容 | [link](https://a.b) | -42 |
        """

        @MainActor
        @Test("A scrolling table keeps its last row", arguments: [
            180.0 as CGFloat, 240, 320, 400, 480, 540, 720,
        ])
        func scrollingTableKeepsItsLastRow(width: CGFloat) throws {
            let view = makeView(Self.markdown, width: width)
            let scrollView = try #require(tableScrollView(in: view))
            let documentView = try #require(scrollView.documentView)

            // A system set to always show scroll bars pushes every scroll view back to
            // legacy scrollers, which are laid out inside the scroll view and take a
            // strip of its height. A table is exactly as tall as its rows, so that
            // strip would come out of the last one.
            scrollView.scrollerStyle = .legacy
            #expect(scrollView.scrollerStyle == .overlay)

            scrollView.tile()
            #expect(scrollView.contentView.bounds.height == documentView.frame.height)
        }

        @MainActor
        @Test("A table only scrolls when its columns outgrow the viewport")
        func tableScrollsOnlyWhenColumnsOutgrowTheViewport() throws {
            let narrow = makeView(Self.markdown, width: 320)
            let narrowScroll = try #require(tableScrollView(in: narrow))
            #expect(try #require(narrowScroll.documentView).frame.width > narrowScroll.contentView.bounds.width)

            let wide = makeView(Self.markdown, width: 720)
            let wideScroll = try #require(tableScrollView(in: wide))
            // Given room, the columns fill the viewport exactly — never a hair over,
            // which would be enough to put a scroller on a table that already fits.
            #expect(try #require(wideScroll.documentView).frame.width == wideScroll.contentView.bounds.width)
        }
    }

    @MainActor
    private func makeView(_ markdown: String, width: CGFloat) -> MarkdownTextView {
        let view = MarkdownTextView()
        view.setContentImmediately(.init(
            parserResult: MarkdownParser().parse(markdown),
            theme: .default
        ))
        view.frame = .init(x: 0, y: 0, width: width, height: view.boundingSize(for: width).height)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        return view
    }

    @MainActor
    private func tableScrollView(in view: MarkdownTextView) -> NSScrollView? {
        view.subviews
            .compactMap { $0 as? TableView }
            .flatMap(\.subviews)
            .compactMap { $0 as? NSScrollView }
            .first
    }
#endif
