//
//  MathRenderer.swift
//  MarkdownView
//
//  Created by 秋星桥 on 5/26/25.
//

import Foundation
import Litext
import LRUCache
import SwiftMath

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public enum MathRenderer {
    static let renderCache = LRUCache<String, PlatformImage>(countLimit: 256)

    private static func preprocessLatex(_ latex: String) -> String {
        latex
            .replacingOccurrences(of: "\\dots", with: "\\ldots")
            .replacingOccurrences(of: "\\implies", with: "\\Rightarrow")
            .replacingOccurrences(of: "\\begin{align}", with: "\\begin{aligned}")
            .replacingOccurrences(of: "\\end{align}", with: "\\end{aligned}")
            .replacingOccurrences(of: "\\begin{align*}", with: "\\begin{aligned}")
            .replacingOccurrences(of: "\\end{align*}", with: "\\end{aligned}")
            .replacingOccurrences(of: "\\begin{cases}", with: "\\left\\{\\begin{matrix}")
            .replacingOccurrences(of: "\\end{cases}", with: "\\end{matrix}\\right.")
            .replacingOccurrences(of: "\\dfrac", with: "\\frac")
            .replacingBoxedCommand()
    }

    public static func renderToImage(
        latex: String,
        fontSize: CGFloat = 16,
        textColor: PlatformColor = .black
    ) -> PlatformImage? {
        let cacheKey = renderCacheKey(for: latex, fontSize: fontSize, textColor: textColor)
        if let cachedImage = renderCache.value(forKey: cacheKey) {
            return cachedImage
        }

        let processedLatex = preprocessLatex(latex)

        #if canImport(UIKit)
            let resolvedTextColor = textColor
        #elseif canImport(AppKit)
            // Resolve dynamic colors in the current appearance context for SwiftMath
            var resolvedTextColor = textColor
            NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                resolvedTextColor = textColor.usingColorSpace(.sRGB) ?? textColor
            }
        #endif

        let mathImage = MTMathImage(
            latex: processedLatex,
            fontSize: fontSize,
            textColor: resolvedTextColor,
            labelMode: .text
        )
        let (error, image) = mathImage.asImage()

        guard error == nil, let image else {
            print("[!] MathRenderer failed to render image for content: \(latex) \(error?.localizedDescription ?? "?")")
            return nil
        }

        #if canImport(UIKit)
            let result = image.withRenderingMode(.alwaysTemplate).withTintColor(.label)
        #elseif canImport(AppKit)
            image.isTemplate = true
            let result = image
        #endif

        renderCache.setValue(result, forKey: cacheKey)
        return result
    }

    private static func renderCacheKey(for latex: String, fontSize: CGFloat, textColor: PlatformColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
            let resolvedColor = textColor.resolvedColor(with: UITraitCollection.current)
            resolvedColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
            // Resolve dynamic colors in the context of the current appearance
            NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                let resolvedColor = textColor.usingColorSpace(.sRGB) ?? textColor
                resolvedColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            }
        #endif
        return "\(latex)#\(fontSize)#\(r),\(g),\(b),\(a)"
    }
}

// MARK: - String Extension

private extension String {
    func substring(with range: NSRange) -> String? {
        guard let swiftRange = Range(range, in: self) else { return nil }
        return String(self[swiftRange])
    }

    func replacingBoxedCommand() -> String {
        var result = self
        while let range = result.range(of: "\\boxed{") {
            let startIndex = range.upperBound
            var braceCount = 1
            var endIndex = startIndex

            // 找到匹配的右大括号
            while endIndex < result.endIndex, braceCount > 0 {
                let char = result[endIndex]
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                }
                if braceCount > 0 {
                    endIndex = result.index(after: endIndex)
                }
            }

            if braceCount == 0 {
                // 提取内容并替换整个\boxed{...}
                let content = String(result[startIndex ..< endIndex])
                let fullRange = result.index(range.lowerBound, offsetBy: 0) ... endIndex
                result.replaceSubrange(fullRange, with: content)
            } else {
                // 如果没有找到匹配的括号，只移除\boxed{
                result.replaceSubrange(range, with: "")
                break
            }
        }
        return result
    }
}
