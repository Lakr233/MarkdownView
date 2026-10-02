import CoreText
@testable import MarkdownView
import Testing

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    struct InlineCodeTests {
        @MainActor
        @Test
        func `A line holding inline code is as tall as one without`() {
            let plain = RenderProbe.view("plain words here", width: 480)
            let code = RenderProbe.view("plain `code` here", width: 480)
            #expect(abs(plain.boundingSize(for: 480).height - code.boundingSize(for: 480).height) < 0.5)
        }

        @MainActor
        @Test
        func `Copying inline code gives back the code alone`() {
            let view = RenderProbe.view("run `swift test` now", width: 480)
            let label = view.textLabelView
            label.selectionRange = NSRange(location: 0, length: label.attributedText.length)
            #expect(label.selectedPlainText()?.contains("run swift test now") == true)
        }

        @MainActor
        @Test
        func `A pill reaches past the text on the side a wrapped span breaks`() throws {
            // At this width the span's leading spacer stays on the line above,
            // so the first code line starts and ends mid-span.
            var theme = MarkdownTheme.default
            theme.colors.codeBackground = .red
            theme.colors.code = .black
            let view = RenderProbe.view(
                "narrow layouts: `supercalifragilisticexpialidocious_and_more_n_1145141919810` end",
                width: 220,
                theme: theme,
            )
            let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)
            let scale = CGFloat(rep.pixelsWide) / view.bounds.width
            func isPill(_ x: Int, _ y: Int) -> Bool {
                guard let color = rep.colorAt(x: x, y: y) else { return false }
                return color.alphaComponent > 0.9 && color.redComponent > 0.8
                    && color.greenComponent < 0.3 && color.blueComponent < 0.3
            }
            // Black code text over the red pill.
            func isInk(_ x: Int, _ y: Int) -> Bool {
                guard let color = rep.colorAt(x: x, y: y) else { return false }
                return color.alphaComponent > 0.9 && color.redComponent < 0.5
            }

            // The first band of rows holding pill pixels is the first code line.
            let rows = (0 ..< rep.pixelsHigh).filter { y in
                stride(from: 0, to: rep.pixelsWide, by: 2).contains { isPill($0, y) }
            }
            let start = try #require(rows.first)
            let band = rows.prefix { $0 - start == rows.firstIndex(of: $0)! }
            let middle = band[band.startIndex + band.count / 2]
            let pill = (0 ..< rep.pixelsWide).filter { isPill($0, middle) }
            // Ink inside the pill's horizontal extent: the code glyphs.
            let inkColumns = try (#require(pill.first) ... pill.last!).filter { x in band.contains { isInk(x, $0) } }
            let pillMax = try #require(pill.last)
            let inkMax = try #require(inkColumns.last)

            // The leading side starts at the label's edge, where the reach is
            // clipped, so only the trailing side is measured.
            #expect(CGFloat(pillMax - inkMax) / scale >= InlineCode.wrappedEndInset + 1)
        }

        @Test
        func `Only <br> reads as a line break`() {
            #expect(InlineCode.isLineBreak("<br>"))
            #expect(InlineCode.isLineBreak("<BR />"))
            #expect(!InlineCode.isLineBreak("<b>"))
        }

        @Test
        func `A run's extent matches its string offsets`() throws {
            let line = Self.line("let x = 1 and code here")
            for run in try #require(CTLineGetGlyphRuns(line) as? [CTRun]) {
                let range = CTRunGetStringRange(run)
                let start = CTLineGetOffsetForStringIndex(line, range.location, nil)
                let end = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil)
                let extent = InlineCode.horizontalExtent(of: run)
                #expect(abs((extent?.0 ?? .nan) - start) < 0.5)
                #expect(abs((extent?.1 ?? .nan) - end) < 0.5)
            }
        }

        /// A caret offset at a change of direction belongs to the run beside
        /// it, so right-to-left runs are checked against their glyphs.
        @Test
        func `A right-to-left run's extent covers its glyphs`() throws {
            let line = Self.line("code مرحبا بالعالم and שלום עולם")
            for run in try #require(CTLineGetGlyphRuns(line) as? [CTRun]) {
                let count = CTRunGetGlyphCount(run)
                var positions = [CGPoint](repeating: .zero, count: count)
                var advances = [CGSize](repeating: .zero, count: count)
                CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
                CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
                let start = positions.map(\.x).min() ?? 0
                let end = zip(positions, advances).map { $0.x + $1.width }.max() ?? 0
                let extent = InlineCode.horizontalExtent(of: run)
                #expect(abs((extent?.0 ?? .nan) - start) < 0.5)
                #expect(abs((extent?.1 ?? .nan) - end) < 0.5)
            }
        }

        private static func line(_ text: String) -> CTLine {
            CTLineCreateWithAttributedString(NSAttributedString(
                string: text,
                attributes: [.font: PlatformFont.systemFont(ofSize: 14)],
            ))
        }
    }
#endif
