//
//  TableTapControl.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit

    /// A tappable region of a table, such as a sortable header, whose hit area can be larger
    /// than what it draws.
    ///
    /// The glyph sits in `glyphFrame`, in the control's own coordinates, so
    /// the table decides where it goes.
    final class TableTapControl: UIControl {
        var handler: (() -> Void)?

        private let imageView = UIImageView()

        var glyphFrame: CGRect = .zero {
            // Set on every layout pass, so an unchanged one is left alone.
            didSet {
                guard oldValue != glyphFrame else { return }
                imageView.frame = glyphFrame
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            imageView.contentMode = .center
            imageView.tintColor = .label
            imageView.isUserInteractionEnabled = false
            addSubview(imageView)
            isAccessibilityElement = true
            accessibilityTraits = .button
            addTarget(self, action: #selector(fire), for: .touchUpInside)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Draws the SF Symbol `name`, or nothing for nil.
        func setSymbol(_ name: String?) {
            guard let name else {
                imageView.image = nil
                return
            }
            let configuration = UIImage.SymbolConfiguration(
                pointSize: TableHeaderAccessory.glyphSize - 2,
                weight: .medium,
            )
            imageView.image = UIImage(systemName: name, withConfiguration: configuration)
        }

        var symbolImage: UIImage? {
            imageView.image
        }

        func setAccessibleTitle(_ title: String?) {
            accessibilityLabel = title
        }

        @objc private func fire() {
            handler?()
        }

        /// What a tap does, without a touch; for accessibility and tests.
        func performTap() {
            handler?()
        }

        override func accessibilityActivate() -> Bool {
            handler?()
            return handler != nil
        }
    }

#elseif canImport(AppKit)
    import AppKit

    /// A clickable region of a table, such as a sortable header, whose hit area can be larger
    /// than what it draws.
    ///
    /// The glyph sits in `glyphFrame`, in the control's own coordinates, so
    /// the table decides where it goes.
    final class TableTapControl: NSView {
        var handler: (() -> Void)?

        private let imageView = NSImageView()

        var glyphFrame: CGRect = .zero {
            // Set on every layout pass, so an unchanged one is left alone.
            didSet {
                guard oldValue != glyphFrame else { return }
                imageView.frame = glyphFrame
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            imageView.imageScaling = .scaleProportionallyDown
            imageView.contentTintColor = .labelColor
            addSubview(imageView)
            setAccessibilityElement(true)
            setAccessibilityRole(.button)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override nonisolated var isFlipped: Bool {
            true
        }

        /// Draws the SF Symbol `name`, or nothing for nil.
        func setSymbol(_ name: String?) {
            guard let name else {
                imageView.image = nil
                return
            }
            let configuration = NSImage.SymbolConfiguration(
                pointSize: TableHeaderAccessory.glyphSize - 2,
                weight: .medium,
            )
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            imageView.image = image?.withSymbolConfiguration(configuration) ?? image
        }

        var symbolImage: NSImage? {
            imageView.image
        }

        func setAccessibleTitle(_ title: String?) {
            setAccessibilityLabel(title)
        }

        /// Children draw; the control takes every click inside it.
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = superview.map { convert(point, from: $0) } ?? point
            return !isHidden && bounds.contains(local) ? self : nil
        }

        override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with _: NSEvent) {}

        override func mouseUp(with event: NSEvent) {
            guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
            handler?()
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }

        /// What a click does, without a mouse; for accessibility and tests.
        func performTap() {
            handler?()
        }

        override func accessibilityPerformPress() -> Bool {
            handler?()
            return handler != nil
        }
    }
#endif
