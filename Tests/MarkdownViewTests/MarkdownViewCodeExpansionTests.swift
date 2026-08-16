//
//  MarkdownViewCodeExpansionTests.swift
//  MarkdownView
//

@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit

    /// A fenced block long enough to be collapsible.
    private func longCodeDocument(lines: Int = 30) -> MarkdownContent {
        let code = (1 ... lines).map { "let line\($0) = \(($0 * 7) % 13)" }.joined(separator: "\n")
        return MarkdownContent(markdown: "Intro.\n\n```swift\n\(code)\n```\n\nOutro.", theme: .default)
    }

    struct MarkdownViewCodeExpansionTests {
        /// The height a view measures must follow `expandedCodeBlocks` on
        /// the very first build — hosts measure rows through views that never
        /// ran a layout pass, so the reservation cannot depend on state a
        /// previous layout synced into the code view.
        @MainActor
        @Test("First measurement honours the expansion flag")
        func firstMeasurementHonoursExpansionFlag() {
            let collapsedView = MarkdownTextView()
            collapsedView.expandedCodeBlocks = []
            collapsedView.setContentImmediately(longCodeDocument(), theme: .default)
            let collapsedHeight = collapsedView.boundingSize(for: 320).height

            let expandedView = MarkdownTextView()
            expandedView.expandedCodeBlocks = [0]
            expandedView.setContentImmediately(longCodeDocument(), theme: .default)
            let expandedHeight = expandedView.boundingSize(for: 320).height

            #expect(expandedHeight > collapsedHeight + 100)
        }

        /// Flipping the flag must re-measure deterministically in both
        /// directions without a layout pass in between.
        @MainActor
        @Test("Expansion toggles re-measure deterministically")
        func expansionTogglesReMeasureDeterministically() {
            let view = MarkdownTextView()
            view.setContentImmediately(longCodeDocument(), theme: .default)
            view.expandedCodeBlocks = []
            let collapsedHeight = view.boundingSize(for: 320).height

            view.expandedCodeBlocks = [0]
            let expandedHeight = view.boundingSize(for: 320).height
            #expect(expandedHeight > collapsedHeight + 100)

            view.expandedCodeBlocks = []
            #expect(view.boundingSize(for: 320).height == collapsedHeight)

            view.expandedCodeBlocks = [0]
            #expect(view.boundingSize(for: 320).height == expandedHeight)
        }

        /// A pooled code view keeps the expansion state of its previous
        /// occupant. Installing new content against a collapsed host must not
        /// reserve the stale expanded height for one build.
        @MainActor
        @Test("Stale expanded code view does not flash into a new document")
        func staleExpandedCodeViewDoesNotFlash() {
            let view = MarkdownTextView()
            view.setContentImmediately(longCodeDocument(), theme: .default)
            view.expandedCodeBlocks = [0]
            let expandedHeight = view.boundingSize(for: 320).height
            #expect(expandedHeight > 0)

            // Same view, new document, host back to collapsed — the sizing
            // pool's exact shape when a row is recycled between messages.
            view.expandedCodeBlocks = []
            view.setContentImmediately(longCodeDocument(lines: 40), theme: .default)
            let rebuiltHeight = view.boundingSize(for: 320).height

            let reference = MarkdownTextView()
            reference.expandedCodeBlocks = []
            reference.setContentImmediately(longCodeDocument(lines: 40), theme: .default)
            let referenceHeight = reference.boundingSize(for: 320).height

            #expect(rebuiltHeight == referenceHeight)
            #expect(rebuiltHeight < expandedHeight)
        }

        /// A rebuild installed while the container has no width must not blank
        /// the code views once the container gets its real size.
        @MainActor
        @Test("Zero-width rebuild keeps code views visible")
        func zeroWidthRebuildKeepsCodeViewsVisible() {
            let view = MarkdownTextView()
            view.frame = .init(x: 0, y: 0, width: 320, height: 800)
            view.setContentImmediately(longCodeDocument(), theme: .default)
            view.layoutIfNeeded()

            // Collapse the container, rebuild, then give it its size back.
            view.frame.size.width = 0
            view.expandedCodeBlocks = [0]
            view.frame.size.width = 320
            view.layoutIfNeeded()

            let codeViews = view.contextViews.compactMap { $0 as? CodeView }
            #expect(!codeViews.isEmpty)
            for codeView in codeViews {
                #expect(!codeView.isHidden)
                #expect(codeView.isExpanded)
            }
        }

        /// Expanding one block must not change the reservation of its
        /// siblings — the reader keeps their place only if nothing above
        /// them reflows.
        @MainActor
        @Test("Expansion is tracked per code block")
        func expansionIsTrackedPerCodeBlock() {
            let blockA = (1 ... 30).map { "let a\($0) = \($0)" }.joined(separator: "\n")
            let blockB = (1 ... 30).map { "let b\($0) = \($0)" }.joined(separator: "\n")
            let markdown = """
            Intro.

            ```swift
            \(blockA)
            ```

            Between.

            ```swift
            \(blockB)
            ```
            """
            let content = MarkdownContent(markdown: markdown, theme: .default)

            let view = MarkdownTextView()
            view.expandedCodeBlocks = []
            view.setContentImmediately(content, theme: .default)
            let allCollapsed = view.boundingSize(for: 320).height

            view.expandedCodeBlocks = [1]
            let secondExpanded = view.boundingSize(for: 320).height
            #expect(secondExpanded > allCollapsed + 100)

            view.expandedCodeBlocks = [0]
            let firstExpanded = view.boundingSize(for: 320).height
            // Symmetric: either single block expanded grows by the same amount.
            #expect(firstExpanded == secondExpanded)

            view.expandedCodeBlocks = [0, 1]
            let bothExpanded = view.boundingSize(for: 320).height
            #expect(bothExpanded > secondExpanded + 100)
        }
    }
#endif
