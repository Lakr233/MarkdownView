//
//  CodeView+Actions.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension CodeView {
    /// How long Copy shows a checkmark after it is tapped.
    static let copyFeedbackDuration: TimeInterval = 1.5

    static let copySymbol = "doc.on.doc"
    static let copiedSymbol = "checkmark"

    /// Swaps Copy for a checkmark, and back after `copyFeedbackDuration`;
    /// another tap restarts the wait.
    func showCopyFeedback() {
        setCopySymbol(Self.copiedSymbol)
        schedule(#selector(resetCopyFeedback), after: Self.copyFeedbackDuration)
    }

    /// Puts Copy back and drops a pending reset, so a view reused for
    /// another block does not show — or later flip — the last one's state.
    @objc func resetCopyFeedback() {
        cancelScheduled(#selector(resetCopyFeedback))
        setCopySymbol(Self.copySymbol)
    }

    /// Asks the provider for this block's buttons and rebuilds them.
    func reloadActions() {
        actions = actionProvider?.codeBlockActions(forLanguage: language.isEmpty ? nil : language) ?? []
        for button in actionButtons {
            button.removeFromSuperview()
        }
        actionButtons = actions.indices.map { makeActionButton(for: actions[$0], tag: $0) }
        for button in actionButtons {
            barView.addSubview(button)
        }
        #if canImport(UIKit)
            setNeedsLayout()
        #elseif canImport(AppKit)
            needsLayout = true
        #endif
    }

    @objc func handleAction(_ sender: Any?) {
        #if canImport(UIKit)
            guard let tag = (sender as? UIView)?.tag else { return }
        #elseif canImport(AppKit)
            guard let tag = (sender as? NSView)?.tag else { return }
        #endif
        guard actions.indices.contains(tag) else { return }
        actions[tag].handler(CodeBlock(language: language.isEmpty ? nil : language, content: content))
    }

    #if canImport(UIKit)
        private func setCopySymbol(_ name: String) {
            let image = UIImage(
                systemName: name,
                withConfiguration: UIImage.SymbolConfiguration(scale: .small)
            )
            copyButton.setImage(image, for: .normal)
        }

        private func makeActionButton(for action: CodeBlockAction, tag: Int) -> UIButton {
            let button = UIButton()
            button.setImage(
                UIImage(
                    systemName: action.systemImage,
                    withConfiguration: UIImage.SymbolConfiguration(scale: .small)
                ),
                for: .normal
            )
            button.tintColor = .label
            button.tag = tag
            button.accessibilityLabel = action.title
            button.addTarget(self, action: #selector(handleAction(_:)), for: .touchUpInside)
            return button
        }

    #elseif canImport(AppKit)
        private func setCopySymbol(_ name: String) {
            copyButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }

        private func makeActionButton(for action: CodeBlockAction, tag: Int) -> NSButton {
            let button = NSButton(title: "", target: self, action: #selector(handleAction(_:)))
            button.image = NSImage(systemSymbolName: action.systemImage, accessibilityDescription: action.title)
            button.bezelStyle = .inline
            button.isBordered = false
            button.contentTintColor = .labelColor
            button.toolTip = action.title
            button.tag = tag
            return button
        }
    #endif
}
