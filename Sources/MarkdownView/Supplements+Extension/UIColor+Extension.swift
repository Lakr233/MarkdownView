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
