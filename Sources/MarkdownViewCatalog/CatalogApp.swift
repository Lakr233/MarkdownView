//
//  CatalogApp.swift
//  MarkdownViewCatalog
//

#if os(macOS)
    import AppKit
    import SwiftUI

    /// A Mac app that lays every block MarkdownView renders out one page per
    /// component, for reviewing and tuning the look.
    ///
    /// `Script/catalog.sh` builds it into an app bundle and opens it.
    @main
    struct CatalogApp: App {
        init() {
            // `swift run` launches a bare executable, which AppKit treats as a
            // background tool: no Dock icon and no key window.
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        var body: some Scene {
            WindowGroup("MarkdownView Catalog") {
                CatalogView()
                    .frame(minWidth: 820, minHeight: 520)
            }
            .defaultSize(width: 1280, height: 860)
        }
    }
#else
    @main
    enum CatalogApp {
        static func main() {
            print("MarkdownViewCatalog runs on macOS only.")
        }
    }
#endif
