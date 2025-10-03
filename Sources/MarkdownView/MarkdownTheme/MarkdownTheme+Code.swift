//
//  MarkdownTheme+Code.swift
//  MarkdownView
//
//  Created by 秋星桥 on 1/23/25.
//

import Foundation
import MarkdownParser
import Splash
import UIKit

public extension MarkdownTheme {
    func codeTheme(withFont font: UIFont) -> Splash.Theme {
        var ret = codeThemeTemplate
        ret.font = .init(size: Double(font.pointSize))
        return ret
    }
}

private extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                dark
            default:
                light
            }
        }
    }
}

private let codeThemeTemplate: Splash.Theme = {
    let tokenColors: [TokenType: UIColor] = [
        .keyword: UIColor(
            light: #colorLiteral(red: 0.948, green: 0.140, blue: 0.547, alpha: 1),
            dark: #colorLiteral(red: 0.948, green: 0.140, blue: 0.547, alpha: 1)
        ),
        .string: UIColor(
            light: #colorLiteral(red: 0.988, green: 0.273, blue: 0.317, alpha: 1),
            dark: #colorLiteral(red: 0.988, green: 0.273, blue: 0.317, alpha: 1)
        ),
        .type: UIColor(
            light: #colorLiteral(red: 0.384, green: 0.698, blue: 0.161, alpha: 1),
            dark: #colorLiteral(red: 0.584, green: 0.898, blue: 0.361, alpha: 1)
        ),
        .call: UIColor(
            light: #colorLiteral(red: 0.384, green: 0.698, blue: 0.161, alpha: 1),
            dark: #colorLiteral(red: 0.584, green: 0.898, blue: 0.361, alpha: 1)
        ),
        .number: UIColor(
            light: #colorLiteral(red: 0.387, green: 0.317, blue: 0.774, alpha: 1),
            dark: #colorLiteral(red: 0.587, green: 0.517, blue: 0.974, alpha: 1)
        ),
        .comment: UIColor(
            light: #colorLiteral(red: 0.424, green: 0.475, blue: 0.529, alpha: 1),
            dark: #colorLiteral(red: 0.424, green: 0.475, blue: 0.529, alpha: 1)
        ),
        .property: UIColor(
            light: #colorLiteral(red: 0.384, green: 0.698, blue: 0.161, alpha: 1),
            dark: #colorLiteral(red: 0.584, green: 0.898, blue: 0.361, alpha: 1)
        ),
        .dotAccess: UIColor(
            light: #colorLiteral(red: 0.384, green: 0.698, blue: 0.161, alpha: 1),
            dark: #colorLiteral(red: 0.584, green: 0.898, blue: 0.361, alpha: 1)
        ),
        .preprocessing: UIColor(
            light: #colorLiteral(red: 0.752, green: 0.326, blue: 0.12, alpha: 19),
            dark: #colorLiteral(red: 0.952, green: 0.526, blue: 0.22, alpha: 19)
        ),
    ]
    return Splash.Theme(
        font: .init(size: 8), // not used
        plainTextColor: .label,
        tokenColors: tokenColors,
        backgroundColor: .clear
    )
}()
