//
//  Ext+UIView.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/8/25.
//

import Foundation

import UIKit

extension UIView {
    var parentViewController: UIViewController? {
        weak var parentResponder: UIResponder? = self
        while let responder = parentResponder {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            parentResponder = responder.next
        }
        return nil
    }
}
