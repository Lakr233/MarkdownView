//
//  MarkdownTheme+Code.swift
//  MarkdownView
//
//  Created by 秋星桥 on 1/23/25.
//

import Foundation
import MarkdownParser
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public extension MarkdownTheme {
    /// The colours code blocks are highlighted with, one per ``SyntaxToken``.
    ///
    /// The defaults are shared instances, so two default themes compare equal.
    struct Syntax: Equatable, @unchecked Sendable {
        public var comment = Defaults.comment
        public var keyword = Defaults.keyword
        public var string = Defaults.string
        public var number = Defaults.number
        public var type = Defaults.type
        public var attribute = Defaults.attribute
        public var meta = Defaults.meta
        public var variable = Defaults.variable

        public init() {}

        public func color(for token: SyntaxToken) -> PlatformColor {
            switch token {
            case .comment: comment
            case .keyword: keyword
            case .string: string
            case .number: number
            case .type: type
            case .attribute: attribute
            case .meta: meta
            case .variable: variable
            }
        }
    }

    static var defaultValueSyntax: Syntax {
        Syntax()
    }

    /// Code is always coloured with ``syntax``; this never changed it.
    @available(*, deprecated, message: "Set `syntax` to change code colours.")
    var codeHighlightTheme: String {
        "xcode"
    }
}

extension MarkdownTheme.Syntax {
    /// One OKLCH lightness per appearance, L 0.65 in light and 0.75 in dark,
    /// so no kind of token stands out by brightness alone; hue tells them
    /// apart.
    enum Defaults {
        static let comment = PlatformColor(light: 0x84919E, dark: 0xA5AFBA)
        static let keyword = PlatformColor(light: 0xB96BCB, dark: 0xD094DD)
        static let string = PlatformColor(light: 0x51A556, dark: 0x7BC27E)
        static let number = PlatformColor(light: 0xCF752D, dark: 0xE49B68)
        static let type = PlatformColor(light: 0x04A3AA, dark: 0x53C1C7)
        static let attribute = PlatformColor(light: 0x5591DD, dark: 0x82B1ED)
        static let meta = PlatformColor(light: 0xB3880F, dark: 0xCEA856)
        static let variable = PlatformColor(light: 0xDB6468, dark: 0xF08E8E)
    }
}
