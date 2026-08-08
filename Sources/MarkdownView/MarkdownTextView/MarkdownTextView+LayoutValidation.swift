//
//  MarkdownTextView+LayoutValidation.swift
//  MarkdownView
//
//  Created by Claude on 8/8/26.
//

import Foundation
import Litext

extension MarkdownTextView {
    /// One laid-out element of the document, in ``MarkdownTextView`` coordinates.
    ///
    /// Text lines contribute their line rect; a line that hosts a context view
    /// contributes the view's frame instead, since the view is what the reader sees.
    struct VerticalLayoutBox {
        let label: String
        let frame: CGRect
    }

    /// Every laid-out element ordered top to bottom.
    ///
    /// Used by tests and by the debug-only ordering check to prove that no block
    /// is drawn on top of another one.
    func verticalLayoutBoxes() -> [VerticalLayoutBox] {
        var boxesByLine: [Int: VerticalLayoutBox] = [:]

        for run in textLabelView.layoutRuns(matching: .font) {
            guard boxesByLine[run.lineIndex] == nil else { continue }
            boxesByLine[run.lineIndex] = .init(
                label: "line \(run.lineIndex)",
                frame: convertFromTextLayout(run.lineRect)
            )
        }

        // Context views are compared by their own frames rather than by the line
        // that reserved them: a view whose line was never laid out still covers
        // the text it is drawn over.
        let contextLines = Set(textLabelView.layoutRuns(matching: .contextView).map(\.lineIndex))
        var boxes = boxesByLine
            .filter { lineIndex, _ in !contextLines.contains(lineIndex) }
            .map(\.value)
        let visibleContextViews = contextViews.lazy.filter {
            $0.superview === self && !$0.isHidden
        }
        boxes.append(contentsOf: visibleContextViews.map {
            .init(label: "\(type(of: $0))", frame: $0.frame)
        })

        return boxes.sorted {
            $0.frame.minY == $1.frame.minY
                ? $0.frame.maxY < $1.frame.maxY
                : $0.frame.minY < $1.frame.minY
        }
    }

    /// Converts a CoreText layout rect into ``MarkdownTextView`` coordinates.
    ///
    /// The text is anchored to the top of the layout container, so the flip must use
    /// the container height the lines were laid out against. `bounds.height` desyncs
    /// whenever the view is resized before the text relayouts.
    func convertFromTextLayout(_ rect: CGRect) -> CGRect {
        CGRect(
            x: textLabelView.frame.minX + rect.minX,
            y: textLabelView.frame.minY + textLabelView.bounds.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    #if DEBUG
        /// Fails in debug builds when a block is laid out on top of the block above it.
        ///
        /// Blocks are stacked, never interleaved, so each element must start at or below
        /// the bottom of its predecessor.
        func assertVerticalLayoutOrdering() {
            let boxes = verticalLayoutBoxes()
            guard boxes.count > 1 else { return }

            for index in boxes.indices.dropFirst() {
                let previous = boxes[index - 1]
                let current = boxes[index]
                guard current.frame.minY < previous.frame.maxY - Self.layoutOrderingTolerance else {
                    continue
                }
                assertionFailure("""
                Markdown blocks are laid out out of order at width \(bounds.width): \
                \(current.label) starts at \(current.frame.minY) while \
                \(previous.label) only ends at \(previous.frame.maxY).
                """)
                return
            }
        }

        /// CoreText line rects include leading, so consecutive lines can report
        /// sub-point overlaps that never reach the pixel grid.
        private static let layoutOrderingTolerance: CGFloat = 0.5
    #endif
}
