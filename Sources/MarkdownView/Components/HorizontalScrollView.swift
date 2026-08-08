//
//  HorizontalScrollView.swift
//  MarkdownView
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    /// A horizontally scrolling view that forwards vertical wheel gestures to
    /// its responder chain so an enclosing vertical scroller can handle them.
    ///
    /// The gesture axis is locked on its first meaningful delta to avoid
    /// switching handlers when trackpad events contain movement on both axes.
    final class HorizontalScrollView: NSScrollView {
        private var lockedToVertical: Bool?

        /// A legacy scroller is laid out inside the scroll view and takes a strip of
        /// its height. The blocks scrolled here — a table, a code block — are exactly
        /// as tall as their content, so that strip came straight out of the last row,
        /// leaving it cut in half behind the scroller whenever the content was wide
        /// enough to scroll at all.
        ///
        /// Assigning the style once is not enough: AppKit follows the system's "show
        /// scroll bars" preference and puts the scroll view back to legacy behind the
        /// assignment, so the style is answered here instead of stored.
        override var scrollerStyle: NSScroller.Style {
            get { .overlay }
            set { _ = newValue }
        }

        override func scrollWheel(with event: NSEvent) {
            if event.phase.isEmpty, event.momentumPhase.isEmpty {
                lockedToVertical = nil
            }
            if event.phase.contains(.began) {
                lockedToVertical = nil
            }
            if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                lockedToVertical = nil
            }

            let deltaX = abs(event.scrollingDeltaX)
            let deltaY = abs(event.scrollingDeltaY)
            if lockedToVertical == nil, deltaX > 0 || deltaY > 0 {
                lockedToVertical = deltaY > deltaX
            }

            if lockedToVertical == true {
                nextResponder?.scrollWheel(with: event)
            } else {
                super.scrollWheel(with: event)
            }
        }
    }
#endif
