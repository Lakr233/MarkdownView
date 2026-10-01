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
    /// Code is always coloured with Xcode's palette; this never changed it.
    @available(*, deprecated, message: "Code blocks always use Xcode's colours.")
    var codeHighlightTheme: String {
        "xcode"
    }
}
