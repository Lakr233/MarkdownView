//
//  BlockquoteBarView.swift
//  MarkdownView
//
//  Created by Claude on 8/8/26.
//

import Foundation

/// Identifies the lines belonging to one blockquote.
///
/// Carried by ``NSAttributedString/Key/blockquoteGroup`` so a layout pass can
/// collect a quote's lines and give its bar a single frame spanning all of them.
final class BlockquoteGroup: Hashable {
    static func == (lhs: BlockquoteGroup, rhs: BlockquoteGroup) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// The vertical bar drawn beside a blockquote.
///
/// A view rather than a line drawing action: actions only run for the lines a
/// redraw touches, which leaves a bar spanning many lines painted in fragments.
final class BlockquoteBarView: PlatformView {
    static let width: CGFloat = 4

    init() {
        super.init(frame: .zero)
        #if canImport(UIKit)
            isUserInteractionEnabled = false
            layer.cornerRadius = Self.width / 2
            layer.cornerCurve = .continuous
        #elseif canImport(AppKit)
            wantsLayer = true
            layer?.cornerRadius = Self.width / 2
        #endif
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var theme: MarkdownTheme = .default

    func setTheme(_ theme: MarkdownTheme) {
        self.theme = theme
        applyThemeColor()
    }

    private func applyThemeColor() {
        let color = theme.colors.body.withAlphaComponent(0.1)
        #if canImport(UIKit)
            backgroundColor = color
        #elseif canImport(AppKit)
            layer?.backgroundColor = color.cgColor
        #endif
    }

    #if canImport(UIKit)
        override func hitTest(_: CGPoint, with _: UIEvent?) -> UIView? {
            nil
        }
    #elseif canImport(AppKit)
        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }

        // AppKit resolves a dynamic color into the layer once, so the stored
        // colour has to be re-resolved when the appearance changes.
        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            applyThemeColor()
        }
    #endif
}
