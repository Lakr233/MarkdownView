//
//  PlatformView+Invalidation.swift
//  MarkdownView
//

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension PlatformView {
    /// Schedules a layout pass: `setNeedsLayout()` on UIKit, `needsLayout`
    /// on AppKit.
    func markNeedsLayout() {
        #if canImport(UIKit)
            setNeedsLayout()
        #elseif canImport(AppKit)
            needsLayout = true
        #endif
    }

    /// Schedules a redraw: `setNeedsDisplay()` on UIKit, `needsDisplay` on
    /// AppKit.
    func markNeedsDisplay() {
        #if canImport(UIKit)
            setNeedsDisplay()
        #elseif canImport(AppKit)
            needsDisplay = true
        #endif
    }
}
