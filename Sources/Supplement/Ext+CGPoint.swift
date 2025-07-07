//
//  Ext+CGPoint.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import Foundation

extension CGPoint {
    func integral(withScaleFactor scaleFactor: CGFloat) -> CGPoint {
        guard scaleFactor > 0.0 else { return self }

        return CGPoint(
            x: round(x * scaleFactor) / scaleFactor,
            y: round(y * scaleFactor) / scaleFactor
        )
    }
}
