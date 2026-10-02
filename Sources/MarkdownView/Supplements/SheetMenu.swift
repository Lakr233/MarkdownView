//
//  SheetMenu.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// What the menu at the top trailing corner of a code or table sheet does.
///
/// The block in the document keeps only Copy and Expand; saving a file and
/// closing the sheet happen from here.
struct SheetMenuActions {
    let copy: () -> Void
    let download: () -> Void
    let close: () -> Void
}

enum SheetMenuText {
    static var more: String {
        String(localized: "More", bundle: .module, comment: "Button that opens a sheet's menu of actions.")
    }

    static var close: String {
        String(localized: "Close", bundle: .module, comment: "Menu item that closes a code or table sheet.")
    }
}

enum SheetMenuSymbol {
    static let menu = "ellipsis"
    static let close = "chevron.down"
}

#if canImport(UIKit)
    extension UIBarButtonItem {
        /// A bar button that opens Copy, Download and Close.
        @MainActor
        static func sheetMenu(_ actions: SheetMenuActions) -> UIBarButtonItem {
            let menu = UIMenu(children: [
                UIAction(title: TableTitleText.copy, image: UIImage(systemName: TableSymbol.copy)) { _ in
                    actions.copy()
                },
                UIAction(title: TableTitleText.download, image: UIImage(systemName: TableSymbol.download)) { _ in
                    actions.download()
                },
                UIAction(title: SheetMenuText.close, image: UIImage(systemName: SheetMenuSymbol.close)) { _ in
                    actions.close()
                },
            ])
            let item = UIBarButtonItem(image: UIImage(systemName: SheetMenuSymbol.menu), menu: menu)
            item.accessibilityLabel = SheetMenuText.more
            return item
        }
    }

#elseif canImport(AppKit)
    /// A borderless button that opens Copy, Download and Close below itself.
    final class SheetMenuButton: NSButton {
        private let actions: SheetMenuActions

        init(actions: SheetMenuActions) {
            self.actions = actions
            super.init(frame: .zero)
            image = NSImage(systemSymbolName: SheetMenuSymbol.menu, accessibilityDescription: SheetMenuText.more)
            imagePosition = .imageOnly
            isBordered = false
            contentTintColor = .labelColor
            toolTip = SheetMenuText.more
            target = self
            action = #selector(showMenu(_:))
            sizeToFit()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func showMenu(_: Any?) {
            let menu = NSMenu()
            menu.addItem(item(TableTitleText.copy, symbol: TableSymbol.copy, action: #selector(copyItem(_:))))
            menu.addItem(item(TableTitleText.download, symbol: TableSymbol.download, action: #selector(downloadItem(_:))))
            menu.addItem(.separator())
            menu.addItem(item(SheetMenuText.close, symbol: SheetMenuSymbol.close, action: #selector(closeItem(_:))))
            menu.popUp(positioning: nil, at: CGPoint(x: 0, y: bounds.height + 4), in: self)
        }

        private func item(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            return item
        }

        @objc private func copyItem(_: Any?) {
            actions.copy()
        }

        @objc private func downloadItem(_: Any?) {
            actions.download()
        }

        @objc private func closeItem(_: Any?) {
            actions.close()
        }
    }
#endif
