import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct MarkdownViewBlockquoteBarTests {
    @MainActor
    @Test("Each blockquote gets one bar spanning all of its lines", arguments: [
        160.0 as CGFloat, 240, 360, 640,
    ])
    func blockquoteBarSpansEveryLine(width: CGFloat) throws {
        let view = makeView("""
        Intro paragraph.

        > A blockquote long enough to wrap into several lines once the available
        > width gets narrow, so a bar that only covers one line is easy to catch.
        >
        > A second paragraph inside the very same quote.

        Between the quotes.

        > A short quote.

        Trailing paragraph.
        """, width: width)

        let bars = view.blockquoteBars.filter { !$0.isHidden }
        #expect(bars.count == 2)

        let quoteLines = quoteLineRects(in: view)
        #expect(quoteLines.count >= 2)

        // Every line of a quote has to sit inside one of the bars vertically.
        for lineRect in quoteLines {
            let covering = bars.first {
                $0.frame.minY <= lineRect.minY + 0.5 && $0.frame.maxY >= lineRect.maxY - 0.5
            }
            #expect(covering != nil, "no bar covers a quoted line at \(lineRect) for width \(width)")
        }

        for bar in bars {
            #expect(bar.frame.width == BlockquoteBarView.width)
            #expect(bar.frame.height > 0)
        }
        #expect(bars[0].frame.maxY <= bars[1].frame.minY)
        // The wrapping quote must be taller than the one-line quote.
        #expect(bars[0].frame.height > bars[1].frame.height)
    }

    @MainActor
    @Test("A document without quotes keeps no bars")
    func documentWithoutQuotesKeepsNoBars() {
        let view = makeView("Just a paragraph.", width: 320)

        #expect(view.blockquoteBars.isEmpty)
    }

    @MainActor
    @Test("Bars are released when the quotes go away")
    func barsAreReleasedWhenQuotesGoAway() {
        let view = makeView("> Quoted.", width: 320)
        #expect(view.blockquoteBars.count == 1)

        view.setContentImmediately(.init(
            parserResult: MarkdownParser().parse("Plain text now."),
            theme: .default
        ))
        layout(view: view, width: 320)

        #expect(view.blockquoteBars.isEmpty)
    }
}

@MainActor
private func makeView(_ markdown: String, width: CGFloat) -> MarkdownTextView {
    let view = MarkdownTextView()
    view.setContentImmediately(.init(
        parserResult: MarkdownParser().parse(markdown),
        theme: .default
    ))
    layout(view: view, width: width)
    return view
}

@MainActor
private func layout(view: MarkdownTextView, width: CGFloat) {
    view.frame = .init(x: 0, y: 0, width: width, height: view.boundingSize(for: width).height)
    #if canImport(UIKit)
        view.setNeedsLayout()
        view.layoutIfNeeded()
    #elseif canImport(AppKit)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    #endif
}

@MainActor
private func quoteLineRects(in view: MarkdownTextView) -> [CGRect] {
    var rectsByLine: [Int: CGRect] = [:]
    for run in view.textLabelView.layoutRuns(matching: .blockquoteGroup) {
        rectsByLine[run.lineIndex] = view.convertFromTextLayout(run.lineRect)
    }
    return rectsByLine.sorted { $0.key < $1.key }.map(\.value)
}
