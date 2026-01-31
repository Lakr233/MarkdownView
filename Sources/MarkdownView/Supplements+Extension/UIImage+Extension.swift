//
//  UIImage+Extension.swift
//  MarkdownView
//
//  Created by 秋星桥 on 8/1/25.
//

#if canImport(UIKit)
    import UIKit

    extension UIImage {
        func resized(to size: CGSize) -> UIImage {
            UIGraphicsImageRenderer(size: size).image { _ in
                self.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    extension NSImage {
        func resized(to size: CGSize) -> NSImage {
            let newImage = NSImage(size: size)
            newImage.lockFocus()
            draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
            newImage.unlockFocus()
            return newImage
        }
    }
#endif
