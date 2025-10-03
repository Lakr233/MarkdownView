//
//  LTXLabel+UIContextMenuInteractionDelegate.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/8/25.
//

import UIKit

extension LTXLabel: UIContextMenuInteractionDelegate {
    public func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        DispatchQueue.main.async {
            guard self.isSelectable else { return }
            guard self.isLocationInSelection(location: location) else { return }
            self.showSelectionMenuController()
        }
        return nil
    }
}
