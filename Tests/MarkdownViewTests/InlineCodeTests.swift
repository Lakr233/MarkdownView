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

        /// Spacers are shared between spans, and a pill that reached out to its
        /// spacers only did so for the span the spacer was first made for.
        @MainActor
        @Test
        func `Every pill is as wide as the first one drawn with its colors`() throws {
            // Colors no other test uses, so the first span here is the first with them.
            var theme = MarkdownTheme.default
            theme.colors.codeBackground = PlatformColor(red: 0.93, green: 0.07, blue: 0.11, alpha: 1)
            theme.colors.code = .black

            func pillWidths(_ markdown: String) throws -> [Int] {
                let view = RenderProbe.view(markdown, width: 480, theme: theme)
                let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: rep)
                func isPill(_ x: Int, _ y: Int) -> Bool {
                    guard let color = rep.colorAt(x: x, y: y) else { return false }
                    return color.alphaComponent > 0.9 && color.redComponent > 0.8
                        && color.greenComponent < 0.3 && color.blueComponent < 0.3
                }
                // Columns that hold any pill pixel, in runs: one run a pill.
                var widths: [Int] = []
                var width = 0
                for x in 0 ..< rep.pixelsWide {
                    if (0 ..< rep.pixelsHigh).contains(where: { isPill(x, $0) }) {
                        width += 1
                    } else if width > 0 {
                        widths.append(width)
                        width = 0
                    }
                }
                if width > 0 { widths.append(width) }
                return widths
            }

            // The same code three times on a line: three pills, not one across the
            // words between them.
            let first = try pillWidths("first `code` then `code` and `code` again")
            #expect(first.count == 3, "\(first)")
            // A pixel apart at most, where an edge falls between two pixels: a
            // pill that reached its spacers would be four points wider.
            #expect((first.max() ?? 0) - (first.min() ?? 0) <= 1, "pills of the same code differ: \(first)")
            // A view built later draws them the same.
            let later = try pillWidths("later `code` once more")
            #expect(later.count == 1, "\(later)")
            #expect(abs((later.first ?? 0) - (first.first ?? 0)) <= 1, "\(later) after \(first)")
            // And so is the pill of code no view has drawn before.
            let other = try pillWidths("other `edoc` here")
            #expect(abs((other.first ?? 0) - (first.first ?? 0)) <= 1, "\(other) after \(first)")
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
