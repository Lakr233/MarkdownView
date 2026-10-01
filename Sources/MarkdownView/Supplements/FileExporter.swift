//
//  FileExporter.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Saves what a code block or a table holds as a file the reader picks a
/// place for, and copies it.
@MainActor
enum FileExporter {
    /// Asks where to save `data` as `fileName`, over the window showing `view`.
    static func export(_ data: Data, fileName: String, from view: PlatformView) {
        #if canImport(UIKit)
            guard let presenter = view.topPresentingViewController else { return }
            // One staging folder, emptied on each export: the picker copies
            // the file out, so nothing staged before is still needed.
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("MarkdownViewExport", isDirectory: true)
            do {
                try? FileManager.default.removeItem(at: directory)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(fileName)
                try data.write(to: url)
                let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
                presenter.present(picker, animated: true)
            } catch {
                assertionFailure("Could not stage \(fileName) for export: \(error)")
            }
        #elseif canImport(AppKit)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = fileName
            panel.canCreateDirectories = true
            let window = view.window
            let save: (NSApplication.ModalResponse) -> Void = { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try data.write(to: url)
                } catch {
                    let alert = NSAlert(error: error)
                    if let window {
                        alert.beginSheetModal(for: window)
                    } else {
                        alert.runModal()
                    }
                }
            }
            if let window {
                panel.beginSheetModal(for: window, completionHandler: save)
            } else {
                save(panel.runModal())
            }
        #endif
    }

    static func copy(_ string: String) {
        #if canImport(UIKit)
            UIPasteboard.general.string = string
        #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}

#if canImport(UIKit)
    extension UIView {
        /// The view controller to present over: the one showing this view, or
        /// whatever it already presents on top.
        var topPresentingViewController: UIViewController? {
            guard var presenter = sequence(first: self as UIResponder, next: \.next)
                .first(where: { $0 is UIViewController }) as? UIViewController
            else { return nil }
            while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
                presenter = presented
            }
            return presenter
        }
    }
#endif
