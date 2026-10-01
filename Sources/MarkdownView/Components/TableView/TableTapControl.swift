//
//  TableTapControl.swift
//  MarkdownView
//

import Foundation

#if canImport(UIKit)
    import UIKit

    /// A tappable region of a table — the expand glyph, the hidden-rows row,
    /// a sortable header — whose hit area can be larger than what it draws.
    ///
    /// The glyph sits in `glyphFrame` and the text in `textFrame`, both in
    /// the control's own coordinates, so the table decides where each goes.
    final class TableTapControl: UIControl {
        var handler: (() -> Void)?

        private let imageView = UIImageView()
        private let label = UILabel()

        var glyphFrame: CGRect = .zero {
            didSet { imageView.frame = glyphFrame }
        }

        var textFrame: CGRect = .zero {
            didSet { label.frame = textFrame }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            imageView.contentMode = .center
            imageView.tintColor = .label
            imageView.isUserInteractionEnabled = false
            label.numberOfLines = 1
            label.isUserInteractionEnabled = false
            addSubview(imageView)
            addSubview(label)
            isAccessibilityElement = true
            accessibilityTraits = .button
            addTarget(self, action: #selector(fire), for: .touchUpInside)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Draws the SF Symbol `name`, or nothing for nil.
        func setSymbol(_ name: String?, fallback: String? = nil) {
            guard let name else {
                imageView.image = nil
                return
            }
            let configuration = UIImage.SymbolConfiguration(
                pointSize: TableHeaderAccessory.glyphSize - 2,
                weight: .medium
            )
            imageView.image = UIImage(systemName: name, withConfiguration: configuration)
                ?? fallback.flatMap { UIImage(systemName: $0, withConfiguration: configuration) }
        }

        var attributedText: NSAttributedString? {
            get { label.attributedText }
            set { label.attributedText = newValue }
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

    /// A clickable region of a table — the expand glyph, the hidden-rows row,
    /// a sortable header — whose hit area can be larger than what it draws.
    ///
    /// The glyph sits in `glyphFrame` and the text in `textFrame`, both in
    /// the control's own coordinates, so the table decides where each goes.
    final class TableTapControl: NSView {
        var handler: (() -> Void)?

        private let imageView = NSImageView()
        private let label = NSTextField(labelWithString: "")

        var glyphFrame: CGRect = .zero {
            didSet { imageView.frame = glyphFrame }
        }

        var textFrame: CGRect = .zero {
            didSet { label.frame = textFrame }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            imageView.imageScaling = .scaleProportionallyDown
            imageView.contentTintColor = .labelColor
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.cell?.truncatesLastVisibleLine = true
            addSubview(imageView)
            addSubview(label)
            setAccessibilityElement(true)
            setAccessibilityRole(.button)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isFlipped: Bool {
            true
        }

        /// Draws the SF Symbol `name`, or nothing for nil.
        func setSymbol(_ name: String?, fallback: String? = nil) {
            guard let name else {
                imageView.image = nil
                return
            }
            let configuration = NSImage.SymbolConfiguration(
                pointSize: TableHeaderAccessory.glyphSize - 2,
                weight: .medium
            )
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
                ?? fallback.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
            imageView.image = image?.withSymbolConfiguration(configuration) ?? image
        }

        var attributedText: NSAttributedString? {
            get { label.attributedStringValue }
            set { label.attributedStringValue = newValue ?? NSAttributedString() }
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
