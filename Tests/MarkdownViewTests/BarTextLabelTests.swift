import Foundation
@testable import MarkdownView
import Testing

/// A bar's caption: one line, cut at the tail when it does not fit, and
/// never in the way of a tap or a click.
@MainActor
struct BarTextLabelTests {
    /// One point per character, so widths read as character counts.
    private func measure(_ string: String) -> CGFloat {
        CGFloat(string.count)
    }

    @Test("Text that fits is shown whole")
    func fittingTextIsWhole() {
        #expect(BarTextLabel.truncated("Table", toFit: 5, measure: measure) == "Table")
        #expect(BarTextLabel.truncated("Table", toFit: 0, measure: measure) == "Table")
    }

    @Test("Text that does not fit is cut at the tail with an ellipsis")
    func longTextIsCut() {
        let cut = BarTextLabel.truncated("Table (110 more rows)", toFit: 8, measure: measure)
        #expect(cut == "Table (…")
        #expect(measure(cut) <= 8)
        #expect(BarTextLabel.truncated("Table", toFit: 1, measure: measure) == "…")
    }

    @Test("A narrow label draws a cut line, and its natural size is the whole text")
    func narrowLabelDrawsCutLine() {
        let label = BarTextLabel()
        label.text = "A caption much wider than its label"
        let natural = label.intrinsicContentSize
        label.frame = CGRect(x: 0, y: 0, width: natural.width / 3, height: natural.height)
        #if canImport(UIKit)
            label.layoutIfNeeded()
        #elseif canImport(AppKit)
            label.layoutSubtreeIfNeeded()
        #endif
        #expect(label.attributedText.string.hasSuffix("…"))
        #expect(label.intrinsicContentSize == natural)
        #expect(!label.isSelectable)
    }
}
