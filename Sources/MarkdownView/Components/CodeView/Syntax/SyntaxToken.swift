import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// What a highlighted range is. Each kind takes the colour highlight.js's
/// `xcode` theme gave the classes it stands for, so code reads as it does in
/// Xcode, in light and dark appearance.
enum SyntaxToken {
    /// `comment`, `quote`.
    case comment
    /// `keyword`, `literal` and markup tag names.
    case keyword
    /// `string`.
    case string
    /// `number`, and `title`: the name a declaration introduces.
    case number
    /// `type`, `built_in`, `class`.
    case type
    /// `attr`: object keys and markup attributes.
    case attribute
    /// `meta`: preprocessor directives, attributes and decorators.
    case meta
    /// `variable`: shell and template variables.
    case variable

    var color: PlatformColor {
        switch self {
        case .comment: Self.commentColor
        case .keyword: Self.keywordColor
        case .string: Self.stringColor
        case .number: Self.numberColor
        case .type: Self.typeColor
        case .attribute: Self.attributeColor
        case .meta: Self.metaColor
        case .variable: Self.variableColor
        }
    }

    // MARK: - Xcode colours

    /// #007400 in light appearance.
    private static let commentColor = dynamicColor(
        light: PlatformColor(red: 0, green: 0.455, blue: 0, alpha: 1),
        dark: PlatformColor(red: 0.447, green: 0.694, blue: 0.427, alpha: 1)
    )

    /// #aa0d91 in light appearance.
    private static let keywordColor = dynamicColor(
        light: PlatformColor(red: 0.667, green: 0.051, blue: 0.569, alpha: 1),
        dark: PlatformColor(red: 0.988, green: 0.373, blue: 0.647, alpha: 1)
    )

    /// #c41a16 in light appearance.
    private static let stringColor = dynamicColor(
        light: PlatformColor(red: 0.769, green: 0.102, blue: 0.086, alpha: 1),
        dark: PlatformColor(red: 0.988, green: 0.416, blue: 0.365, alpha: 1)
    )

    /// #1c00cf in light appearance.
    private static let numberColor = dynamicColor(
        light: PlatformColor(red: 0.11, green: 0, blue: 0.812, alpha: 1),
        dark: PlatformColor(red: 0.557, green: 0.627, blue: 0.988, alpha: 1)
    )

    /// #5c2699 in light appearance.
    private static let typeColor = dynamicColor(
        light: PlatformColor(red: 0.361, green: 0.149, blue: 0.6, alpha: 1),
        dark: PlatformColor(red: 0.631, green: 0.475, blue: 0.886, alpha: 1)
    )

    /// #836c28 in light appearance.
    private static let attributeColor = dynamicColor(
        light: PlatformColor(red: 0.514, green: 0.424, blue: 0.157, alpha: 1),
        dark: PlatformColor(red: 0.835, green: 0.749, blue: 0.427, alpha: 1)
    )

    /// #643820 in light appearance.
    private static let metaColor = dynamicColor(
        light: PlatformColor(red: 0.392, green: 0.22, blue: 0.125, alpha: 1),
        dark: PlatformColor(red: 0.765, green: 0.569, blue: 0.439, alpha: 1)
    )

    /// #3f6e74 in light appearance.
    private static let variableColor = dynamicColor(
        light: PlatformColor(red: 0.247, green: 0.431, blue: 0.455, alpha: 1),
        dark: PlatformColor(red: 0.431, green: 0.714, blue: 0.745, alpha: 1)
    )

    private static func dynamicColor(light: PlatformColor, dark: PlatformColor) -> PlatformColor {
        #if canImport(UIKit)
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        #elseif canImport(AppKit)
            NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        #endif
    }
}
