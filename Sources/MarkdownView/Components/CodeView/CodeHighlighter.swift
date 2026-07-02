//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Foundation
import Highlightr
import LRUCache
import OrderedCollections

#if canImport(UIKit)
    import UIKit

    public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
    import AppKit

    public typealias PlatformColor = NSColor
#endif

private let kMaxCacheSize = 64 // for each language
private let kPrefixLength = 8

struct CodeHighlightRequest {
    let key: Int
    let content: String
    let language: String?
}

@MainActor
public final class CodeHighlighter {
    public typealias HighlightMap = [NSRange: PlatformColor]

    public private(set) var renderCache = LRUCache<Int, HighlightMap>(countLimit: 256)
    private let highlightr = Highlightr()

    static let highlightDidUpdateNotification = Notification.Name("wiki.qaq.MarkdownView.CodeHighlighter.highlightDidUpdate")

    private let worker = HighlightWorker()
    private var pendingRequests: OrderedDictionary<Int, CodeHighlightRequest> = [:]
    private var inflightKey: Int?

    private init() {
        highlightr?.setTheme(to: "xcode")
    }

    public static let current = CodeHighlighter()

    // MARK: - Dynamic Color Mapping

    /// Maps light mode colors from Xcode theme to dynamic light/dark pairs
    private nonisolated static let colorMapping: [String: (light: PlatformColor, dark: PlatformColor)] = [
        // Background and default text
        "#000000": (light: .black, dark: .white),
        "#ffffff": (light: .white, dark: .black),

        // Comment/Quote - green
        "#007400": (
            light: PlatformColor(red: 0, green: 0.455, blue: 0, alpha: 1),
            dark: PlatformColor(red: 0.447, green: 0.694, blue: 0.427, alpha: 1)
        ),

        // Keyword/Attribute/Literal/Name/Selector/Tag - purple/pink
        "#aa0d91": (
            light: PlatformColor(red: 0.667, green: 0.051, blue: 0.569, alpha: 1),
            dark: PlatformColor(red: 0.988, green: 0.373, blue: 0.647, alpha: 1)
        ),

        // Variable/Template-variable - teal
        "#3f6e74": (
            light: PlatformColor(red: 0.247, green: 0.431, blue: 0.455, alpha: 1),
            dark: PlatformColor(red: 0.431, green: 0.714, blue: 0.745, alpha: 1)
        ),

        // String - red
        "#c41a16": (
            light: PlatformColor(red: 0.769, green: 0.102, blue: 0.086, alpha: 1),
            dark: PlatformColor(red: 0.988, green: 0.416, blue: 0.365, alpha: 1)
        ),

        // Link/Regexp - blue
        "#0e0eff": (
            light: PlatformColor(red: 0.055, green: 0.055, blue: 1, alpha: 1),
            dark: PlatformColor(red: 0.384, green: 0.494, blue: 1, alpha: 1)
        ),

        // Number/Symbol/Title/Bullet - dark blue
        "#1c00cf": (
            light: PlatformColor(red: 0.11, green: 0, blue: 0.812, alpha: 1),
            dark: PlatformColor(red: 0.557, green: 0.627, blue: 0.988, alpha: 1)
        ),

        // Meta/Section - brown
        "#643820": (
            light: PlatformColor(red: 0.392, green: 0.22, blue: 0.125, alpha: 1),
            dark: PlatformColor(red: 0.765, green: 0.569, blue: 0.439, alpha: 1)
        ),

        // Built-in/Class/Params/Type - dark purple
        "#5c2699": (
            light: PlatformColor(red: 0.361, green: 0.149, blue: 0.6, alpha: 1),
            dark: PlatformColor(red: 0.631, green: 0.475, blue: 0.886, alpha: 1)
        ),

        // Attr - olive
        "#836c28": (
            light: PlatformColor(red: 0.514, green: 0.424, blue: 0.157, alpha: 1),
            dark: PlatformColor(red: 0.835, green: 0.749, blue: 0.427, alpha: 1)
        ),

        // Selector-class/Selector-id - tan
        "#9b703f": (
            light: PlatformColor(red: 0.608, green: 0.439, blue: 0.247, alpha: 1),
            dark: PlatformColor(red: 0.847, green: 0.706, blue: 0.518, alpha: 1)
        ),
    ]

    /// Creates a dynamic color that adapts to light/dark mode
    nonisolated static func dynamicColor(light: PlatformColor, dark: PlatformColor) -> PlatformColor {
        #if canImport(UIKit)
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        #elseif canImport(AppKit)
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    dark
                } else {
                    light
                }
            }
        #endif
    }

    /// Converts a static color to a dynamic color if it matches a known light mode color
    nonisolated static func makeDynamic(_ color: PlatformColor) -> PlatformColor {
        // Get the hex representation of the color
        let hexKey = color.hexString.lowercased()

        // Check if we have a mapping for this color
        if let mapping = colorMapping[hexKey] {
            return dynamicColor(light: mapping.light, dark: mapping.dark)
        }

        // For unknown colors, try to create a lighter version for dark mode
        return createAdaptiveColor(from: color)
    }

    /// Creates an adaptive color by adjusting brightness for dark mode
    private nonisolated static func createAdaptiveColor(from color: PlatformColor) -> PlatformColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        #elseif canImport(AppKit)
            let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
            rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        #endif

        // For dark colors (brightness < 0.5), create a lighter version for dark mode
        if brightness < 0.5 {
            let darkModeBrightness = min(1.0, brightness + 0.4)
            let darkModeSaturation = max(0, saturation - 0.1)

            #if canImport(UIKit)
                let darkModeColor = UIColor(hue: hue, saturation: darkModeSaturation, brightness: darkModeBrightness, alpha: alpha)
                return dynamicColor(light: color, dark: darkModeColor)
            #elseif canImport(AppKit)
                let darkModeColor = NSColor(hue: hue, saturation: darkModeSaturation, brightness: darkModeBrightness, alpha: alpha)
                return dynamicColor(light: color, dark: darkModeColor)
            #endif
        }

        return color
    }
}

// MARK: - Color Extension for Hex

private extension PlatformColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
            getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
            let rgbColor = usingColorSpace(.deviceRGB) ?? self
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

public extension CodeHighlighter {
    func key(for content: String, language: String?) -> Int {
        var hasher = Hasher()
        hasher.combine(content)
        hasher.combine(language?.lowercased() ?? "")
        return hasher.finalize()
    }

    func highlight(
        key: Int?,
        content: String,
        language: String?,
        theme: MarkdownTheme = .default // doesn't matter we use color only
    ) -> [NSRange: PlatformColor] {
        let key = key ?? self.key(for: content, language: language)
        if let value = renderCache.value(forKey: key) {
            return value
        }
        let highlightedAttributeString = highlightedAttributeString(
            language: language ?? "",
            content: content,
            theme: theme
        )
        let map = Self.extractColorAttributes(from: highlightedAttributeString)
        renderCache.setValue(map, forKey: key)
        return map
    }
}

extension CodeHighlighter {
    func cachedHighlightMap(for key: Int) -> HighlightMap? {
        renderCache.value(forKey: key)
    }

    func scheduleHighlight(requests: [CodeHighlightRequest]) {
        var pending: OrderedDictionary<Int, CodeHighlightRequest> = [:]
        for request in requests {
            guard request.key != inflightKey else { continue }
            guard renderCache.value(forKey: request.key) == nil else { continue }
            pending[request.key] = request
        }
        pendingRequests = pending
        processNextRequestIfNeeded()
    }

    private func processNextRequestIfNeeded() {
        guard inflightKey == nil else { return }
        guard let next = pendingRequests.elements.first else { return }
        pendingRequests.removeValue(forKey: next.key)
        let request = next.value
        inflightKey = request.key
        worker.highlight(content: request.content, language: request.language) { [weak self] map in
            self?.finishHighlight(key: request.key, map: map)
        }
    }

    private func finishHighlight(key: Int, map: HighlightMap) {
        inflightKey = nil
        defer { processNextRequestIfNeeded() }
        guard renderCache.value(forKey: key) == nil else { return }
        renderCache.setValue(map, forKey: key)
        NotificationCenter.default.post(name: Self.highlightDidUpdateNotification, object: nil)
    }
}

private extension CodeHighlighter {
    func highlightedAttributeString(language: String, content: String, theme: MarkdownTheme) -> NSAttributedString {
        guard let highlightr else {
            return NSAttributedString(string: content)
        }

        let lang = language.isEmpty ? "plaintext" : language.lowercased()
        let highlighted = highlightr.highlight(content, as: lang)

        guard let result = highlighted else {
            return NSAttributedString(string: content)
        }

        let finalizer = NSMutableAttributedString(attributedString: result)
        finalizer.addAttributes([
            .font: theme.fonts.code,
        ], range: .init(location: 0, length: finalizer.length))
        return finalizer
    }

    nonisolated static func extractColorAttributes(from attributedString: NSAttributedString) -> HighlightMap {
        var attributes: [NSRange: PlatformColor] = [:]
        var dynamicColorCache: [PlatformColor: PlatformColor] = [:]

        attributedString.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: attributedString.length)
        ) { value, range, _ in
            guard let color = value as? PlatformColor else { return }
            // Convert to dynamic color for dark mode support
            let dynamicColor: PlatformColor
            if let cached = dynamicColorCache[color] {
                dynamicColor = cached
            } else {
                dynamicColor = CodeHighlighter.makeDynamic(color)
                dynamicColorCache[color] = dynamicColor
            }
            attributes[range] = dynamicColor
        }

        return attributes
    }
}

private final class HighlightWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "wiki.qaq.MarkdownView.CodeHighlighter", qos: .userInitiated)
    private lazy var highlightr: Highlightr? = {
        let highlightr = Highlightr()
        highlightr?.setTheme(to: "xcode")
        return highlightr
    }()

    func highlight(
        content: String,
        language: String?,
        completion: @escaping @MainActor (CodeHighlighter.HighlightMap) -> Void
    ) {
        queue.async { [self] in
            let map = makeHighlightMap(content: content, language: language)
            Task { @MainActor in
                completion(map)
            }
        }
    }

    private func makeHighlightMap(content: String, language: String?) -> CodeHighlighter.HighlightMap {
        let language = language ?? ""
        let lang = language.isEmpty ? "plaintext" : language.lowercased()
        guard let highlightr,
              let highlighted = highlightr.highlight(content, as: lang)
        else { return [:] }
        return CodeHighlighter.extractColorAttributes(from: highlighted)
    }
}

public extension CodeHighlighter.HighlightMap {
    func apply(to content: String, with theme: MarkdownTheme) -> NSMutableAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CodeViewConfiguration.codeLineSpacing

        let plainTextColor = theme.colors.code
        let attributedContent: NSMutableAttributedString = .init(
            string: content,
            attributes: [
                .font: theme.fonts.code,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: plainTextColor,
            ]
        )

        let length = attributedContent.length
        for (range, color) in self {
            guard range.location >= 0, range.upperBound <= length else { continue }
            guard color != plainTextColor else { continue }
            attributedContent.addAttributes([.foregroundColor: color], range: range)
        }
        return attributedContent
    }
}
