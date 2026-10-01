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

/// The name a code block is saved under: `code` and the extension its
/// language is usually saved with.
enum CodeFileName {
    private static let extensions: [String: String] = [
        "bash": "sh", "sh": "sh", "shell": "sh", "zsh": "sh", "fish": "fish",
        "c": "c", "h": "h", "cpp": "cpp", "c++": "cpp", "cc": "cpp", "hpp": "hpp",
        "objc": "m", "objective-c": "m", "objectivec": "m",
        "swift": "swift", "kotlin": "kt", "kt": "kt", "java": "java", "scala": "scala",
        "go": "go", "golang": "go", "rust": "rs", "rs": "rs", "zig": "zig",
        "python": "py", "py": "py", "ruby": "rb", "rb": "rb", "php": "php", "perl": "pl",
        "lua": "lua", "r": "r", "dart": "dart", "elixir": "ex", "haskell": "hs",
        "javascript": "js", "js": "js", "jsx": "jsx", "typescript": "ts", "ts": "ts", "tsx": "tsx",
        "html": "html", "xml": "xml", "css": "css", "scss": "scss", "vue": "vue",
        "json": "json", "yaml": "yaml", "yml": "yaml", "toml": "toml", "ini": "ini",
        "sql": "sql", "graphql": "graphql", "markdown": "md", "md": "md",
        "dockerfile": "dockerfile", "makefile": "mk", "diff": "diff", "patch": "patch",
        "csharp": "cs", "c#": "cs", "cs": "cs", "fsharp": "fs", "powershell": "ps1", "ps1": "ps1",
        "latex": "tex", "tex": "tex", "text": "txt", "plaintext": "txt", "txt": "txt",
    ]

    static func fileName(forLanguage language: String) -> String {
        let key = language.trimmingCharacters(in: .whitespaces).lowercased()
        return "code." + (extensions[key] ?? "txt")
    }
}

/// The text a code block's sheet shows: its highlighted code, titled by its
/// language.
struct CodeSheetContent {
    let title: String
    let code: NSAttributedString

    @MainActor
    init(_ codeView: CodeView) {
        title = codeView.language.isEmpty ? CodeSheetText.code : codeView.language
        code = codeView.textView.attributedText
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
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(close)
            )
        }

        @objc private func close() {
            dismiss(animated: true)
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

            let closeButton = NSButton(title: TableSheetText.done, target: nil, action: #selector(close(_:)))
            closeButton.target = self
            closeButton.bezelStyle = .rounded
            closeButton.keyEquivalent = "\r"
            closeButton.sizeToFit()
            closeButton.frame.origin = CGPoint(
                x: size.width - margin - closeButton.frame.width,
                y: size.height - barHeight + (barHeight - closeButton.frame.height) / 2
            )
            closeButton.autoresizingMask = [.minXMargin, .minYMargin]
            container.addSubview(closeButton)
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
