//
//  MathRenderer.swift
//  MarkdownView
//
//  Created by 秋星桥 on 5/26/25.
//

import Foundation
import LRUCache
import SwiftMath
import UIKit

enum MathRenderer {
    enum ContentType {
        case text
        case math
    }

    static let renderCache = LRUCache<String, UIImage>(countLimit: 256)

    struct ParsedContent {
        let type: ContentType
        let content: String
        let attributes: [NSAttributedString.Key: Any]

        init(type: ContentType, content: String, attributes: [NSAttributedString.Key: Any] = [:]) {
            self.type = type
            self.content = content
            self.attributes = attributes
        }
    }

    static let mathPattern: NSRegularExpression? = {
        let pattern = ###"\$\$([\s\S]*?)\$\$|\$([\s\S]*?)\$|\\\[([\s\S]*?)\\\]|\\\(([\s\S]*?)\\\)"###
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            assertionFailure("failed to create regex for math pattern")
            return nil
        }
        return regex
    }()

    static func parseMathInText(_ text: String, textAttributes: [NSAttributedString.Key: Any] = [:]) -> [ParsedContent] {
        var results: [ParsedContent] = []

        guard let regex = mathPattern else {
            assertionFailure()
            results.append(ParsedContent(type: .text, content: text, attributes: textAttributes))
            return results
        }

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        var lastIndex = 0

        for match in matches {
            if match.range.location > lastIndex {
                let beforeRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                if let beforeText = text.substring(with: beforeRange), !beforeText.isEmpty {
                    results.append(ParsedContent(type: .text, content: beforeText, attributes: textAttributes))
                }
            }

            // Check all possible capturing groups for math content
            var mathFormula: String?
            for group in 1 ..< match.numberOfRanges {
                let mathRange = match.range(at: group)
                if mathRange.location != NSNotFound, mathRange.length > 0,
                   let formula = text.substring(with: mathRange)
                {
                    mathFormula = formula
                    break
                }
            }
            if let mathFormula {
                results.append(ParsedContent(type: .math, content: mathFormula, attributes: textAttributes))
            }

            lastIndex = match.range.location + match.range.length
        }

        if lastIndex < text.count {
            let remainingRange = NSRange(location: lastIndex, length: text.count - lastIndex)
            if let remainingText = text.substring(with: remainingRange), !remainingText.isEmpty {
                results.append(ParsedContent(type: .text, content: remainingText, attributes: textAttributes))
            }
        }

        if results.isEmpty {
            results.append(ParsedContent(type: .text, content: text, attributes: textAttributes))
        }

        return results
    }

    static func renderToImage(
        latex: String,
        fontSize: CGFloat = 16,
        textColor: UIColor = .black
    ) -> UIImage? {
        if let cachedImage = renderCache.value(forKey: latex) {
            return cachedImage
        }

        let mathImage = MTMathImage(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            labelMode: .text
        )
        let (error, image) = mathImage.asImage()
        guard error == nil, let image else { return nil }
        renderCache.setValue(image, forKey: latex)

        return image
    }
}

// MARK: - String Extension

private extension String {
    func substring(with range: NSRange) -> String? {
        guard let swiftRange = Range(range, in: self) else { return nil }
        return String(self[swiftRange])
    }
}
