//
//  MarkdownTextView+MathPreview.swift
//  MarkdownView
//
//  Created by Willow Zhang on 11/13/25
//

#if canImport(UIKit)
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

            let navigation = UINavigationController(rootViewController: MathPreviewController(image: image))
            // An equation is a line or two tall; a half-height sheet shows it
            // without taking over the screen, and can still be pulled up.
            // visionOS has no detents; its page sheet is already a window-sized panel.
            navigation.modalPresentationStyle = .pageSheet
            #if !os(visionOS)
                if let sheet = navigation.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }
            #endif

            var presenter = window?.rootViewController
            while let presented = presenter?.presentedViewController {
                presenter = presented
            }
            presenter?.present(navigation, animated: true)
        }
    }

    /// Shows a rendered equation centred, shrunk to fit and zoomable.
    private final class MathPreviewController: UIViewController, UIScrollViewDelegate {
        private let image: UIImage
        private let scrollView = UIScrollView()
        private let imageView: UIImageView

        init(image: UIImage) {
            self.image = image
            imageView = UIImageView(image: image)
            // The equation is a template image; untinted it takes the app's
            // accent colour instead of the text's.
            imageView.tintColor = .label
            super.init(nibName: nil, bundle: nil)
            title = "Math Equation"
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                systemItem: .close,
                primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
            )

            scrollView.delegate = self
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.contentInsetAdjustmentBehavior = .never
            scrollView.addSubview(imageView)
            view.addSubview(scrollView)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let frame = view.bounds.inset(by: view.safeAreaInsets)
            guard scrollView.frame != frame else { return }
            scrollView.frame = frame
            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size

            // Never enlarge past the rendered size, which would blur it.
            let padding: CGFloat = 20
            let fit = min(
                1,
                max(1, frame.width - padding * 2) / max(1, image.size.width),
                max(1, frame.height - padding * 2) / max(1, image.size.height)
            )
            scrollView.minimumZoomScale = fit
            scrollView.maximumZoomScale = max(fit * 4, 2)
            scrollView.zoomScale = fit
            centerImage()
        }

        func viewForZooming(in _: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_: UIScrollView) {
            centerImage()
        }

        private func centerImage() {
            let size = scrollView.bounds.size
            let content = imageView.frame.size
            scrollView.contentInset = UIEdgeInsets(
                top: max(0, (size.height - content.height) / 2),
                left: max(0, (size.width - content.width) / 2),
                bottom: 0,
                right: 0
            )
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
