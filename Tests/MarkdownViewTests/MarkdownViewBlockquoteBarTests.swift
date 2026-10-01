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
    func blockquoteBarSpansEveryLine(width: CGFloat) {
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
    @Test("Quoted text is indented past its bar and never laid out over it", arguments: [
        160.0 as CGFloat, 240, 360, 640,
    ])
    func quotedTextStaysClearOfTheBar(width: CGFloat) throws {
        let view = makeView(Self.quotesDocument, width: width)
        let bars = view.blockquoteBars.filter { !$0.isHidden }
        #expect(bars.count == 2)

        let runs = view.textLabelView.layoutRuns(matching: .blockquoteGroup)
        let string = view.textLabelView.attributedText.string as NSString
        #expect(!runs.isEmpty)
        for run in runs {
            let rect = view.convertFromTextLayout(run.rect)
            let bar = try #require(bars.first {
                $0.frame.minY <= rect.midY && $0.frame.maxY >= rect.midY
            }, "no bar beside quoted run at \(rect) for width \(width)")
            #expect(bar.frame.maxX <= rect.minX, "quoted run at \(rect) overlaps its bar at width \(width)")
            #expect(rect.maxY <= view.bounds.height + 0.5, "quoted run at \(rect) falls below the measured height")

            // The right inset is gone, so make sure no visible text spills past
            // the view. A space that ends a wrapped line hangs past the edge by
            // design and draws nothing.
            let runText = string.substring(with: run.stringRange)
            guard !runText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            #expect(rect.maxX <= view.bounds.width + 0.5, "quoted run [\(runText)] at \(rect) overflows width \(width)")
        }

        // Every quoted character is laid out: a measurement that came up one line
        // short would drop the tail of the quote.
        let text = view.textLabelView.attributedText
        var quotedLength = 0
        text.enumerateAttribute(
            .blockquoteGroup,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, range, _ in
            if value != nil { quotedLength += range.length }
        }
        let laidOutLength = runs.reduce(0) { $0 + $1.stringRange.length }
        #expect(laidOutLength == quotedLength)
    }

    @MainActor
    @Test("Quotes keep their text, indent and copy output byte for byte")
    func quotesKeepTheirText() throws {
        let view = makeView(Self.quotesDocument, width: 360)
        let text = view.textLabelView.attributedText

        // Inline code is drawn as a pill, held between two placeholder characters
        // that copying strips again.
        let placeholder = "\u{FFFC}"
        let rendered = Self.quotesCopiedText.replacingOccurrences(
            of: " code ",
            with: " \(placeholder)code\(placeholder) "
        )
        #expect(text.string == rendered)

        view.textLabelView.selectAll()
        #expect(view.textLabelView.selectedPlainText() == Self.quotesCopiedText)

        let linkRange = (text.string as NSString).range(of: "link")
        let link = text.attribute(.link, at: linkRange.location, effectiveRange: nil)
        #expect((link as? URL)?.absoluteString ?? (link as? String) == "https://example.com/q")

        for needle in ["Outer quote", "Nested quote", "Second quote"] {
            let style = try #require(RenderProbe.paragraphStyle(at: needle, in: text))
            #expect(style.firstLineHeadIndent == 16)
            #expect(style.headIndent == 16)
            #expect(style.tailIndent == 0)
        }
    }

    @MainActor
    @Test("No paragraph in a rendered document narrows its lines with a negative tail indent")
    func noNegativeTailIndent() {
        // A negative tail indent sends the text layout down its two-pass
        // measurement for the whole document, on every streamed update.
        for markdown in [Self.quotesDocument, RenderProbeDocument.everything] {
            let text = makeView(markdown, width: 480).textLabelView.attributedText
            text.enumerateAttribute(
                .paragraphStyle,
                in: NSRange(location: 0, length: text.length),
                options: []
            ) { value, range, _ in
                guard let style = value as? NSParagraphStyle else { return }
                #expect(style.tailIndent >= 0, "negative tail indent at \(range)")
            }
        }
    }

    private static let quotesDocument = """
    Intro paragraph.

    > Outer quote with **bold**, `code` and a [link](https://example.com/q) that \
    wraps once the width gets narrow enough to need a second line.
    >
    > > Nested quote inside the outer one.

    Between the quotes.

    > Second quote.

    Trailing paragraph.
    """

    private static let quotesCopiedText = """
    Intro paragraph.
    Outer quote with bold, code and a link that \
    wraps once the width gets narrow enough to need a second line.
    Nested quote inside the outer one.
    Between the quotes.
    Second quote.
    Trailing paragraph.

    """

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
