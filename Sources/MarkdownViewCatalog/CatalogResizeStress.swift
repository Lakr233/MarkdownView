//
//  CatalogResizeStress.swift
//  MarkdownViewCatalog
//

#if os(macOS)
    import AppKit

    /// Sweeps the window's width back and forth, then quits.
    ///
    /// Launch with `CATALOG_RESIZE_STRESS=<sample id>` under Instruments to
    /// profile a live resize the same way every run. The page fills the
    /// window, so every frame reflows the rendered markdown.
    @MainActor
    enum CatalogResizeStress {
        static var sampleID: CatalogSample.ID? {
            ProcessInfo.processInfo.environment["CATALOG_RESIZE_STRESS"]
        }

        static func run(select: (CatalogSample.ID) -> Void, fill: () -> Void) async {
            guard let sampleID else { return }
            select(sampleID)
            fill()
            // Let the first layout and code highlighting land.
            try? await Task.sleep(for: .seconds(2))
            guard let window = NSApplication.shared.windows.first(where: \.isVisible) else { return }

            let origin = window.frame.origin
            let height = window.frame.height
            let range: ClosedRange<CGFloat> = 900 ... 1700
            let frames = 60 * 10
            let clock = ContinuousClock()
            var durations: [Duration] = []
            for frame in 0 ..< frames {
                // A triangle wave, one sweep each way every two seconds.
                let phase = CGFloat(frame % 120) / 60
                let t = phase <= 1 ? phase : 2 - phase
                let width = range.lowerBound + (range.upperBound - range.lowerBound) * t
                durations.append(clock.measure {
                    window.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
                })
                try? await Task.sleep(for: .milliseconds(16))
            }
            report(durations, sampleID: sampleID)
            NSApplication.shared.terminate(nil)
        }

        /// Prints how long each synchronous resize — layout and display — took.
        private static func report(_ durations: [Duration], sampleID: CatalogSample.ID) {
            let ms = durations.map { Double($0.components.attoseconds) / 1e15 + Double($0.components.seconds) * 1000 }.sorted()
            func percentile(_ p: Double) -> Double {
                ms[min(ms.count - 1, Int(Double(ms.count) * p))]
            }
            let mean = ms.reduce(0, +) / Double(ms.count)
            print(String(
                format: "resize %@: %d frames, mean %.2f ms, p50 %.2f, p95 %.2f, max %.2f",
                sampleID, ms.count, mean, percentile(0.5), percentile(0.95), ms.last ?? 0,
            ))
        }
    }
#endif
