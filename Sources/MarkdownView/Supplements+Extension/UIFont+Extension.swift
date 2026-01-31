//
//  UIFont+Extension.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

#if canImport(UIKit)
    import UIKit

    public extension UIFont {
        var bold: UIFont {
            UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold)!, size: 0)
        }

        var italic: UIFont {
            UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitItalic)!, size: 0)
        }

        var monospaced: UIFont {
            let settings = [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
            ]]

            let attributes = [UIFontDescriptor.AttributeName.featureSettings: settings]
            let newDescriptor = fontDescriptor.addingAttributes(attributes)
            return UIFont(descriptor: newDescriptor, size: 0)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    public extension NSFont {
        var bold: NSFont {
            NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask)
        }

        var italic: NSFont {
            NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
        }

        var monospaced: NSFont {
            let settings = [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
            ]]

            let attributes: [NSFontDescriptor.AttributeName: Any] = [.featureSettings: settings]
            let newDescriptor = fontDescriptor.addingAttributes(attributes)
            return NSFont(descriptor: newDescriptor, size: 0) ?? self
        }
    }
#endif
