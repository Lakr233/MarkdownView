//
//  CatalogSnapshot.swift
//  MarkdownViewCatalog
//

#if os(macOS)
    import AppKit

    /// Writes one PNG of the window per catalog page, then quits.
    ///
    /// Launch with `CATALOG_SNAPSHOT_DIR=/some/dir` to compare the look before
    /// and after a styling change without clicking through every page.
    @MainActor
    enum CatalogSnapshot {
        static var directory: URL? {
            ProcessInfo.processInfo.environment["CATALOG_SNAPSHOT_DIR"]
                .map { URL(fileURLWithPath: $0, isDirectory: true) }
        }

        static func run(select: (CatalogSample.ID) -> Void) async {
            guard let directory else { return }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for sample in CatalogSample.all {
                select(sample.id)
                // Let layout settle and code highlighting land.
                try? await Task.sleep(for: .milliseconds(1200))
                write(to: directory.appendingPathComponent("\(sample.id).png"))
            }
            NSApplication.shared.terminate(nil)
        }

        private static func write(to url: URL) {
            // The frame view, so the title bar and toolbar are in the picture too.
            guard let content = NSApplication.shared.windows.first(where: \.isVisible)?.contentView,
                  let view = content.superview ?? Optional(content),
                  let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds)
            else { return }
            view.cacheDisplay(in: view.bounds, to: representation)
            try? representation.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
#endif
