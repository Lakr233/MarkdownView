@testable import MarkdownView
import SwiftUI
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct MarkdownViewSizingProbeTests {
    @MainActor
    @Test("Zero-width probe does not report the concrete width as a minimum")
    func zeroWidthProbeReportsSmallMinimum() throws {
        let view = MarkdownTextView()
        view.setContentImmediately(.init(markdown: """
        A paragraph long enough to wrap when narrow, repeated to gain both
        width and height so a wrong minimum is easy to detect.
        """))
        let coordinator = MarkdownViewCoordinator()

        let concrete = try #require(coordinator.sizeThatFits(
            ProposedViewSize(width: 800, height: nil), for: view
        ))
        #expect(concrete.width == 800)

        // SwiftUI uses a zero-width proposal to learn the minimum width.
        // Reporting the last concrete width here pins the hosting window's
        // minimum width, making it impossible to shrink the window.
        if let minimum = coordinator.sizeThatFits(
            ProposedViewSize(width: 0, height: nil), for: view
        ) {
            #expect(minimum.width < 300)
        }

        // Ideal-size probes must still answer with the last concrete width.
        let ideal = try #require(coordinator.sizeThatFits(
            ProposedViewSize(width: nil, height: nil), for: view
        ))
        #expect(ideal.width == 800)
    }
}
