//
//  MarkdownTextView+MathPreview.swift
//  MarkdownView
//
//  Created by Willow Zhang on 11/13/25
//

#if canImport(UIKit)
    import QuickLook
    import UIKit

    extension MarkdownTextView {
        func presentMathPreview(for latexContent: String, theme: MarkdownTheme) {
            // Render at higher resolution for preview (2x)
            let previewFontSize = theme.fonts.body.pointSize * 2

            guard let image = MathRenderer.renderToImage(
                latex: latexContent,
                fontSize: previewFontSize,
                textColor: theme.colors.body
            ) else {
                print("[MarkdownView] Failed to render LaTeX for preview: \(latexContent)")
                return
            }

            guard let pngData = image.pngData() else { return }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")

            do {
                try pngData.write(to: tempURL)

                let previewItem = MathPreviewItem(url: tempURL, title: "Math Equation")
                let controller = MathPreviewController(item: previewItem) {
                    try? FileManager.default.removeItem(at: tempURL)
                }

                window?.rootViewController?.present(controller, animated: true)
            } catch {
                print("[MarkdownView] Failed to create temp file for math preview: \(error)")
            }
        }
    }

    // MARK: - QuickLook Support

    private class MathPreviewController: QLPreviewController {
        private let myDataSource: MathPreviewDataSource

        init(item: MathPreviewItem, cleanup: @escaping () -> Void) {
            myDataSource = MathPreviewDataSource(item: item, cleanup: cleanup)
            super.init(nibName: nil, bundle: nil)
            dataSource = myDataSource
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private class MathPreviewItem: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        let previewItemTitle: String?

        init(url: URL, title: String) {
            previewItemURL = url
            previewItemTitle = title
        }
    }

    private class MathPreviewDataSource: NSObject, QLPreviewControllerDataSource {
        let item: MathPreviewItem
        let cleanup: () -> Void

        init(item: MathPreviewItem, cleanup: @escaping () -> Void) {
            self.item = item
            self.cleanup = cleanup
        }

        func numberOfPreviewItems(in _: QLPreviewController) -> Int {
            1
        }

        func previewController(_: QLPreviewController, previewItemAt _: Int) -> any QLPreviewItem {
            item
        }

        deinit {
            cleanup()
        }
    }

#elseif canImport(AppKit)
    import AppKit

    extension MarkdownTextView {
        func presentMathPreview(for _: String, theme _: MarkdownTheme) {
            // Math preview disabled on macOS
        }
    }
#endif
