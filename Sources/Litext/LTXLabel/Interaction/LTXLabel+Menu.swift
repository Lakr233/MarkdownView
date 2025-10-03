//
//  LTXLabel+Menu.swift
//  Litext
//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import UIKit

// MARK: - Menu Controller

extension LTXLabel {
    func showSelectionMenuController() {
        guard let range = selectionRange, range.length > 0 else { return }

        let rects: [CGRect] = textLayout.rects(for: range).map {
            convertRectFromTextLayout($0, insetForInteraction: true)
        }

        let menu = UIMenuController.shared
        if menu.isMenuVisible { return }

        let firstRect = rects.first!
        let menuRect = rects.count == 1 ? firstRect : rects.reduce(firstRect) { $0.union($1) }

        menu.menuItems = [
            UIMenuItem(title: LocalizedText.copy, action: #selector(copyText)),
            UIMenuItem(title: LocalizedText.selectAll, action: #selector(selectAllText)),
        ]

        menu.setTargetRect(menuRect, in: self)
        menu.setMenuVisible(true, animated: true)
    }

    func hideSelectionMenuController() {
        let menu = UIMenuController.shared
        menu.setMenuVisible(false, animated: true)
    }

    @objc
    func copyText() {
        _ = copySelectedText()
    }

    func copyFromSubviewsRecursively(in subview: UIView) -> Bool {
        if let label = subview as? LTXLabel {
            let copiedText = label.copySelectedText()
            if copiedText.length > 0 {
                UIPasteboard.general.string = copiedText.string
                return true
            }
        } else {
            for subview in subview.subviews {
                if copyFromSubviewsRecursively(in: subview) {
                    return true
                }
            }
        }
        return false
    }

    func copyFromSubviewsRecursively() -> Bool {
        for subview in subviews {
            if copyFromSubviewsRecursively(in: subview) {
                return true
            }
        }
        return false
    }
}

extension LTXLabel {
    func canShowMenuController() -> Bool {
        if let range = selectionRange, range.length > 0 {
            return true
        }
        return false
    }
}
