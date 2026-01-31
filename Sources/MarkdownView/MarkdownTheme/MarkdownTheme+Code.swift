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
    /// The Highlightr theme name to use for code highlighting
    /// Available themes: "xcode", "github", "monokai", etc.
    var codeHighlightTheme: String {
        "xcode"
    }
}
