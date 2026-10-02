//
//  CodeSheet.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// The text a code block's sheet shows: its highlighted code, titled by its
/// language, and what its menu copies and saves.
struct CodeSheetContent {
    let title: String
    let code: NSAttributedString
    /// The code as copied and saved.
    let text: String
    let fileName: String

    @MainActor
    init(_ codeView: CodeView) {
        title = codeView.language.isEmpty ? CodeSheetText.code : codeView.language
        code = codeView.textView.attributedText
        text = codeView.content
        fileName = CodeFileName.fileName(forLanguage: codeView.language)
    }

    /// Copy, Download and Close for the sheet showing this code from `view`.
    @MainActor
    func menuActions(from view: @escaping () -> PlatformView?, close: @escaping () -> Void) -> SheetMenuActions {
        let text = text
        let fileName = fileName
        return SheetMenuActions(
            copy: {
                FileExporter.copy(text)
                #if canImport(UIKit) && !os(visionOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            },
            download: {
                guard let view = view() else { return }
                FileExporter.export(Data(text.utf8), fileName: fileName, from: view)
            },
            close: close
        )
    }
}

enum CodeSheetText {
    static var code: String {
        String(localized: "Code", bundle: .module, comment: "Title of a code block's sheet when it names no language.")
    }
}

#if canImport(UIKit)
    @MainActor
    enum CodeSheetPresenter {
        /// Presents `codeView`'s code in a half-height sheet that can be
        /// pulled up to full height.
        static func present(_ codeView: CodeView) {
            guard let presenter = codeView.topPresentingViewController else { return }
            let controller = CodeSheetViewController(content: CodeSheetContent(codeView))
            let navigation = UINavigationController(rootViewController: controller)
            navigation.modalPresentationStyle = .formSheet
            #if !os(visionOS)
                if let sheet = navigation.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }
            #endif
            presenter.present(navigation, animated: true)
        }
    }

    /// A code block's text, highlighted, in a selectable text view.
    final class CodeSheetViewController: UIViewController {
        let textView = UITextView()
        private let content: CodeSheetContent

        init(content: CodeSheetContent) {
            self.content = content
            super.init(nibName: nil, bundle: nil)
            title = content.title
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            textView.isEditable = false
            textView.isSelectable = true
            textView.backgroundColor = .clear
            textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
            textView.attributedText = content.code
            textView.frame = view.bounds
            textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(textView)
            navigationItem.rightBarButtonItem = .sheetMenu(content.menuActions(
                from: { [weak self] in self?.view },
                close: { [weak self] in self?.dismiss(animated: true) }
            ))
        }
    }

#elseif canImport(AppKit)
    @MainActor
    enum CodeSheetPresenter {
        /// Presents `codeView`'s code in a sheet half as tall as its window.
        static func present(_ codeView: CodeView) {
            guard let window = codeView.window else { return }
            let size = CGSize(
                width: min(900, max(420, window.frame.width * 0.8)),
                height: max(240, window.frame.height * 0.5)
            )
            let sheet = CodeSheetWindow(content: CodeSheetContent(codeView), size: size)
            window.beginSheet(sheet)
        }
    }

    /// A code block's text, highlighted, in a selectable text view.
    final class CodeSheetWindow: NSWindow {
        let textView = NSTextView()

        init(content: CodeSheetContent, size: CGSize) {
            super.init(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: false
            )
            isReleasedWhenClosed = false
            minSize = CGSize(width: 320, height: 200)
            title = content.title

            let barHeight: CGFloat = 48
            let margin: CGFloat = 16
            let container = NSView(frame: CGRect(origin: .zero, size: size))

            let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height - barHeight))
            scrollView.autoresizingMask = [.width, .height]
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.drawsBackground = false
            textView.frame = scrollView.bounds
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.textContainerInset = NSSize(width: 12, height: 12)
            textView.autoresizingMask = [.width, .height]
            // Code keeps its lines, as in the block, and scrolls sideways.
            textView.isHorizontallyResizable = true
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: .greatestFiniteMagnitude
            )
            textView.textStorage?.setAttributedString(content.code)
            scrollView.documentView = textView
            container.addSubview(scrollView)

            let menuButton = SheetMenuButton(actions: content.menuActions(
                from: { [weak container] in container },
                close: { [weak self] in self?.close(nil) }
            ))
            menuButton.frame.origin = CGPoint(
                x: size.width - margin - menuButton.frame.width,
                y: size.height - barHeight + (barHeight - menuButton.frame.height) / 2
            )
            menuButton.autoresizingMask = [.minXMargin, .minYMargin]
            container.addSubview(menuButton)
            contentView = container
        }

        override func cancelOperation(_: Any?) {
            close(nil)
        }

        @objc private func close(_: Any?) {
            if let parent = sheetParent {
                parent.endSheet(self)
            } else {
                orderOut(nil)
            }
        }
    }
#endif
