//
//  Ext+UITextView.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import UIKit

public extension UITextView {
    func convertPointToTextContainer(_ point: CGPoint) -> CGPoint {
        let insets = textContainerInset
        return CGPoint(x: point.x - insets.left, y: point.y - insets.top)
    }

    func convertPointFromTextContainer(_ point: CGPoint) -> CGPoint {
        let insets = textContainerInset
        return CGPoint(x: point.x + insets.left, y: point.y + insets.top)
    }

    func convertRectToTextContainer(_ rect: CGRect) -> CGRect {
        let insets = textContainerInset
        return rect.offsetBy(dx: -insets.left, dy: -insets.top)
    }

    func convertRectFromTextContainer(_ rect: CGRect) -> CGRect {
        let insets = textContainerInset
        return rect.offsetBy(dx: insets.left, dy: insets.top)
    }
}
