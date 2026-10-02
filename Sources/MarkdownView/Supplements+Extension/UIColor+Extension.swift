//
//  UIColor+Extension.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2025/1/7.
//

#if canImport(UIKit)
    import UIKit

    extension UIColor {
        convenience init(light: UIColor, dark: UIColor) {
            self.init(dynamicProvider: { $0.userInterfaceStyle == .dark ? dark : light })
        }
    }

#elseif canImport(AppKit)
    import AppKit

    extension NSColor {
        convenience init(light: NSColor, dark: NSColor) {
            self.init(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    dark
                } else {
                    light
                }
            }
        }
    }
#endif

#if canImport(UIKit) || canImport(AppKit)
    extension PlatformColor {
        /// An opaque sRGB colour from `0xRRGGBB`.
        convenience init(hex: UInt32) {
            self.init(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1,
            )
        }

        /// An opaque colour that follows the appearance.
        convenience init(light: UInt32, dark: UInt32) {
            self.init(light: PlatformColor(hex: light), dark: PlatformColor(hex: dark))
        }
    }
#endif
