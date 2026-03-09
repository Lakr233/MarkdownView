//
//  WatchMarkdownTheme.swift
//  WatchMarkdownView
//

import CoreText
import Foundation

public struct WatchMarkdownTheme: @unchecked Sendable {
    // MARK: - Scale

    public var bodySize: CGFloat = 16
    public var codeScale: CGFloat = 0.85

    // MARK: - Colors (CGColor — UIColor/NSColor not available on watchOS)

    public var textColor: CGColor = .init(gray: 1, alpha: 1)
    public var codeColor: CGColor = .init(red: 0.85, green: 0.85, blue: 0.95, alpha: 1)
    public var codeBackgroundColor: CGColor = .init(gray: 0.15, alpha: 1)
    public var linkColor: CGColor = .init(red: 0.35, green: 0.65, blue: 1.0, alpha: 1)
    public var accentColor: CGColor = .init(red: 1.0, green: 0.6, blue: 0.2, alpha: 1)
    public var blockquoteBorderColor: CGColor = .init(gray: 0.45, alpha: 1)
    public var blockquoteTextColor: CGColor = .init(gray: 0.72, alpha: 1)
    public var tableBorderColor: CGColor = .init(gray: 0.35, alpha: 1)
    public var tableHeaderBackgroundColor: CGColor = .init(gray: 0.2, alpha: 1)
    public var tableStripeColor: CGColor = .init(gray: 0.12, alpha: 1)
    public var separatorColor: CGColor = .init(gray: 0.3, alpha: 1)

    // MARK: - Spacing

    public var blockSpacing: CGFloat = 8
    public var tableCellPadding: CGFloat = 8
    public var tableMaxColumnWidth: CGFloat = 180
    public var listIndent: CGFloat = 6
    public var blockquoteBarWidth: CGFloat = 3

    // MARK: - Default

    public static let `default` = WatchMarkdownTheme()
    public init() {}
}

// MARK: - Font Accessors

extension WatchMarkdownTheme {
    var bodyFont: CTFont {
        systemFont(size: bodySize)
    }

    var boldFont: CTFont {
        boldSystemFont(size: bodySize)
    }

    var italicFont: CTFont {
        italicSystemFont(size: bodySize)
    }

    var boldItalicFont: CTFont {
        boldItalicSystemFont(size: bodySize)
    }

    var codeFont: CTFont {
        monoFont(size: ceil(bodySize * codeScale))
    }

    var h1Font: CTFont {
        boldSystemFont(size: ceil(bodySize * 1.6))
    }

    var h2Font: CTFont {
        boldSystemFont(size: ceil(bodySize * 1.4))
    }

    var h3Font: CTFont {
        boldSystemFont(size: ceil(bodySize * 1.2))
    }

    var h4Font: CTFont {
        boldSystemFont(size: ceil(bodySize * 1.1))
    }
}

// MARK: - Font Helpers (file-private)

private func systemFont(size: CGFloat) -> CTFont {
    CTFontCreateUIFontForLanguage(.system, size, nil)
        ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
}

private func boldSystemFont(size: CGFloat) -> CTFont {
    let base = systemFont(size: size)
    return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .boldTrait, .boldTrait)
        ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
}

private func italicSystemFont(size: CGFloat) -> CTFont {
    let base = systemFont(size: size)
    return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .italicTrait, .italicTrait)
        ?? CTFontCreateWithName("Helvetica-Oblique" as CFString, size, nil)
}

private func boldItalicSystemFont(size: CGFloat) -> CTFont {
    let base = systemFont(size: size)
    let traits: CTFontSymbolicTraits = [.boldTrait, .italicTrait]
    return CTFontCreateCopyWithSymbolicTraits(base, size, nil, traits, traits)
        ?? boldSystemFont(size: size)
}

private func monoFont(size: CGFloat) -> CTFont {
    // Menlo is available on watchOS via the system font stack
    if let f = CTFontCreateWithName("Menlo-Regular" as CFString, size, nil) as CTFont? {
        // CTFontCreateWithName never returns nil in practice; verify it resolved
        let name = CTFontCopyFullName(f) as String
        if name.localizedCaseInsensitiveContains("menlo") { return f }
    }
    return CTFontCreateWithName("CourierNewPSMT" as CFString, size, nil)
}
