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
        let language = codeView.language
        // The fence's word as written, with only its first letter raised:
        // "swift" reads as "Swift", and "objectiveC" keeps its inner capital.
        title = language.isEmpty ? CodeSheetText.code : language.prefix(1).uppercased() + language.dropFirst()
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
            close: close,
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
                close: { [weak self] in self?.dismiss(animated: true) },
            ))
        }
    }

#elseif canImport(AppKit)
    @MainActor
    enum CodeSheetPresenter {
        /// Presents `codeView`'s code in a sheet fitted to the code: as wide
        /// as its longest line, up to a reading width past which lines wrap.
        static func present(_ codeView: CodeView) {
            guard let window = codeView.window else { return }
            let content = CodeSheetContent(codeView)
            let size = CodeSheetGeometry.size(
                for: content.code,
                maxHeight: window.frame.height * 0.8,
            )
            let sheet = CodeSheetWindow(content: content, size: size)
            window.beginSheet(sheet)
        }
    }

    /// The sheet's size, from the code it shows.
    enum CodeSheetGeometry {
        /// Lines longer than this wrap rather than widening the sheet.
        static let maxTextWidth: CGFloat = 600
        static let minSize = CGSize(width: 320, height: 200)
        static let barHeight: CGFloat = 48
        static let textInset = NSSize(width: 12, height: 12)
        /// NSTextContainer's default padding at each end of a line.
        static let lineFragmentPadding: CGFloat = 5

        /// The text width `code` lays out at: its longest line, capped at
        /// ``maxTextWidth``.
        static func textWidth(for code: NSAttributedString) -> CGFloat {
            let natural = code.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
            ).width
            return min(maxTextWidth, ceil(natural))
        }

        static func size(for code: NSAttributedString, maxHeight: CGFloat) -> CGSize {
            let textWidth = textWidth(for: code)
            let textHeight = code.boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
            ).height
            let width = textWidth + 2 * (textInset.width + lineFragmentPadding)
            let height = barHeight + ceil(textHeight) + 2 * textInset.height
            return CGSize(
                width: max(minSize.width, width),
                height: min(max(minSize.height, height), max(minSize.height, maxHeight)),
            )
        }
    }

    /// A code block's text, highlighted, in a selectable text view.
    final class CodeSheetWindow: NSWindow {
        let textView = NSTextView()
        /// The language, or "Code"; a sheet draws no window title.
        let titleLabel = NSTextField(labelWithString: "")

        init(content: CodeSheetContent, size: CGSize) {
            super.init(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: false,
            )
            isReleasedWhenClosed = false
            minSize = CodeSheetGeometry.minSize
            title = content.title

            let barHeight = CodeSheetGeometry.barHeight
            let margin: CGFloat = 16
            let container = NSView(frame: CGRect(origin: .zero, size: size))

            let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height - barHeight))
            scrollView.autoresizingMask = [.width, .height]
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.drawsBackground = false
            textView.frame = scrollView.bounds
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.textContainerInset = CodeSheetGeometry.textInset
            textView.textContainer?.lineFragmentPadding = CodeSheetGeometry.lineFragmentPadding
            textView.autoresizingMask = [.width, .height]
            // The sheet is sized to the code, so lines only wrap past the
            // reading width, or when the sheet is resized narrower.
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
            textView.textStorage?.setAttributedString(content.code)
            scrollView.documentView = textView
            container.addSubview(scrollView)

            let menuButton = SheetMenuButton(actions: content.menuActions(
                from: { [weak container] in container },
                close: { [weak self] in self?.close(nil) },
            ))
            menuButton.frame.origin = CGPoint(
                x: size.width - margin - menuButton.frame.width,
                y: size.height - barHeight + (barHeight - menuButton.frame.height) / 2,
            )
            menuButton.autoresizingMask = [.minXMargin, .minYMargin]
            container.addSubview(menuButton)

            titleLabel.stringValue = content.title
            titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            titleLabel.textColor = .labelColor
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.sizeToFit()
            titleLabel.frame = CGRect(
                x: margin,
                y: size.height - barHeight + (barHeight - titleLabel.frame.height) / 2,
                width: max(0, menuButton.frame.minX - margin * 2),
                height: titleLabel.frame.height,
            )
            titleLabel.autoresizingMask = [.width, .minYMargin]
            container.addSubview(titleLabel)
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
