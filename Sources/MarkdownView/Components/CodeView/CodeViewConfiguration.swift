//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Litext

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@MainActor
enum CodeViewConfiguration {
    nonisolated static let barPadding: CGFloat = 8
    nonisolated static let codePadding: CGFloat = 8
    nonisolated static let codeLineSpacing: CGFloat = 4
    nonisolated static let lineNumberWidth: CGFloat = 40
    nonisolated static let lineNumberPadding: CGFloat = 8

    static func intrinsicHeight(
        for content: String,
        theme: MarkdownTheme = .default
    ) -> CGFloat {
        let numberOfRows = content.components(separatedBy: .newlines).count
        return intrinsicHeight(lineCount: numberOfRows, theme: theme)
    }

    static func intrinsicHeight(
        lineCount: Int,
        theme: MarkdownTheme = .default
    ) -> CGFloat {
        let font = theme.fonts.code
        #if canImport(UIKit)
            let lineHeight = font.lineHeight
        #elseif canImport(AppKit)
            let lineHeight = font.ascender + abs(font.descender) + font.leading
        #endif
        let barHeight = lineHeight + barPadding * 2
        let codeHeight = lineHeight * CGFloat(lineCount)
            + codePadding * 2
            + codeLineSpacing * CGFloat(max(lineCount - 1, 0))
        return ceil(barHeight + codeHeight)
    }
}

#if canImport(UIKit)
    extension CodeView {
        func configureSubviews() {
            setupViewAppearance()
            setupBarView()
            setupButtons()
            setupScrollView()
            setupTextView()
            setupLineNumberView()
        }

        private func setupViewAppearance() {
            layer.cornerRadius = 8
            layer.cornerCurve = .continuous
            // Not clipped, so a selection's handles can reach past the code;
            // the bar rounds its own corners instead.
            clipsToBounds = false
            backgroundColor = .gray.withAlphaComponent(0.05)
        }

        private func setupBarView() {
            barView.backgroundColor = .gray.withAlphaComponent(0.05)
            barView.layer.cornerRadius = layer.cornerRadius
            barView.layer.cornerCurve = .continuous
            barView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            addSubview(barView)
            barView.addSubview(languageLabel)
        }

        private func setupButtons() {
            setupPreviewButton()
            setupCopyButton()
        }

        private func setupPreviewButton() {
            let previewImage = UIImage(
                systemName: "eye",
                withConfiguration: UIImage.SymbolConfiguration(scale: .small)
            )
            previewButton.setImage(previewImage, for: .normal)
            previewButton.tintColor = .label
            previewButton.addTarget(self, action: #selector(handlePreview(_:)), for: .touchUpInside)
            barView.addSubview(previewButton)
        }

        private func setupCopyButton() {
            let copyImage = UIImage(
                systemName: CodeView.copySymbol,
                withConfiguration: UIImage.SymbolConfiguration(scale: .small)
            )
            copyButton.setImage(copyImage, for: .normal)
            copyButton.tintColor = .label
            copyButton.addTarget(self, action: #selector(handleCopy(_:)), for: .touchUpInside)
            barView.addSubview(copyButton)
        }

        private func setupScrollView() {
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.alwaysBounceVertical = false
            scrollView.alwaysBounceHorizontal = false
            scrollView.blankLeadingWidth = CodeViewConfiguration.codePadding
            scrollView.blankTrailingWidth = CodeViewConfiguration.codePadding
            addSubview(scrollView)
        }

        private func setupTextView() {
            textView.backgroundColor = .clear
            textView.preferredMaxLayoutWidth = .greatestFiniteMagnitude
            textView.isSelectable = true
            textView.selectionBackgroundColor = theme.colors.selectionBackground
            scrollView.addSubview(textView)
        }

        private func setupLineNumberView() {
            lineNumberView.backgroundColor = .clear
            // Under the code, so a selection's handles draw over the gutter.
            insertSubview(lineNumberView, belowSubview: scrollView)
            updateLineNumberView()
        }

        func performLayout() {
            let labelSize = languageLabel.intrinsicContentSize
            let barHeight = max(languageLabel.font?.lineHeight ?? 16, labelSize.height) + CodeViewConfiguration.barPadding * 2

            layoutBarView(barHeight: barHeight, labelSize: labelSize)
            layoutButtons()
            layoutLineNumberView(barHeight: barHeight)
            layoutScrollViewAndTextView(barHeight: barHeight)
        }

        /// Lays the bar's buttons out from the trailing edge: Copy, then
        /// Preview when there is a handler, then the host's actions.
        private func layoutButtons() {
            let buttonSize = CGSize(width: 44, height: 44)
            previewButton.isHidden = previewAction == nil
            var trailing = barView.bounds.width
            for button in [copyButton, previewButton] + actionButtons.reversed() where !button.isHidden {
                trailing -= buttonSize.width
                button.frame = CGRect(
                    x: trailing,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
            }
        }

        private func layoutBarView(barHeight: CGFloat, labelSize: CGSize) {
            barView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: barHeight))
            languageLabel.frame = CGRect(
                origin: CGPoint(x: CodeViewConfiguration.barPadding, y: CodeViewConfiguration.barPadding),
                size: labelSize
            )
        }

        private func layoutLineNumberView(barHeight: CGFloat) {
            let lineNumberSize = lineNumberView.intrinsicContentSize
            lineNumberView.frame = CGRect(
                x: 0,
                y: barHeight,
                width: lineNumberSize.width,
                height: bounds.height - barHeight
            )
        }

        private func layoutScrollViewAndTextView(barHeight: CGFloat) {
            let textContentSize = textView.intrinsicContentSize
            let lineNumberWidth = lineNumberView.intrinsicContentSize.width

            scrollView.frame = CGRect(
                x: lineNumberWidth,
                y: barHeight,
                width: bounds.width - lineNumberWidth,
                height: bounds.height - barHeight
            )

            textView.frame = CGRect(
                x: CodeViewConfiguration.codePadding,
                y: CodeViewConfiguration.codePadding,
                width: max(scrollView.bounds.width - CodeViewConfiguration.codePadding * 2, textContentSize.width),
                height: textContentSize.height
            )

            scrollView.contentSize = CGSize(
                width: textView.frame.width + CodeViewConfiguration.codePadding * 2,
                height: 0
            )
        }
    }

#elseif canImport(AppKit)
    extension CodeView {
        func configureSubviews() {
            setupViewAppearance()
            setupBarView()
            setupButtons()
            setupScrollView()
            setupTextView()
            setupLineNumberView()
        }

        private func setupViewAppearance() {
            wantsLayer = true
            layer?.cornerRadius = 8
            layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.05).cgColor
        }

        private func setupBarView() {
            barView.wantsLayer = true
            barView.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.05).cgColor
            addSubview(barView)
            barView.addSubview(languageLabel)
        }

        private func setupButtons() {
            setupPreviewButton()
            setupCopyButton()
        }

        private func setupPreviewButton() {
            if let previewImage = NSImage(systemSymbolName: "eye", accessibilityDescription: nil) {
                previewButton.image = previewImage
            }
            previewButton.target = self
            previewButton.action = #selector(handlePreview(_:))
            previewButton.bezelStyle = .inline
            previewButton.isBordered = false
            previewButton.contentTintColor = .labelColor
            barView.addSubview(previewButton)
        }

        private func setupCopyButton() {
            if let copyImage = NSImage(systemSymbolName: CodeView.copySymbol, accessibilityDescription: nil) {
                copyButton.image = copyImage
            }
            copyButton.target = self
            copyButton.action = #selector(handleCopy(_:))
            copyButton.bezelStyle = .inline
            copyButton.isBordered = false
            copyButton.contentTintColor = .labelColor
            barView.addSubview(copyButton)
        }

        private func setupScrollView() {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.drawsBackground = false
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.contentInsets = NSEdgeInsets(
                top: CodeViewConfiguration.codePadding,
                left: CodeViewConfiguration.codePadding,
                bottom: CodeViewConfiguration.codePadding,
                right: CodeViewConfiguration.codePadding
            )
            addSubview(scrollView)
        }

        private func setupTextView() {
            textView.wantsLayer = true
            textView.layer?.backgroundColor = NSColor.clear.cgColor
            textView.preferredMaxLayoutWidth = .greatestFiniteMagnitude
            textView.isSelectable = true
            textView.selectionBackgroundColor = theme.colors.selectionBackground
            scrollView.documentView = textView
        }

        private func setupLineNumberView() {
            lineNumberView.wantsLayer = true
            lineNumberView.layer?.backgroundColor = NSColor.clear.cgColor
            addSubview(lineNumberView)
            updateLineNumberView()
        }

        func performLayout() {
            let labelSize = languageLabel.intrinsicContentSize
            let font = languageLabel.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let lineHeight = font.ascender + abs(font.descender) + font.leading
            let barHeight = max(lineHeight, labelSize.height) + CodeViewConfiguration.barPadding * 2

            layoutBarView(barHeight: barHeight, labelSize: labelSize)
            layoutButtons()
            layoutLineNumberView(barHeight: barHeight)
            layoutScrollViewAndTextView(barHeight: barHeight)
        }

        /// Lays the bar's buttons out from the trailing edge: Copy, then
        /// Preview when there is a handler, then the host's actions.
        private func layoutButtons() {
            let buttonSize = CGSize(width: 44, height: 44)
            previewButton.isHidden = previewAction == nil
            var trailing = barView.bounds.width
            for button in [copyButton, previewButton] + actionButtons.reversed() where !button.isHidden {
                trailing -= buttonSize.width
                button.frame = CGRect(
                    x: trailing,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
            }
        }

        private func layoutBarView(barHeight: CGFloat, labelSize: CGSize) {
            barView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: barHeight))
            languageLabel.frame = CGRect(
                origin: CGPoint(x: CodeViewConfiguration.barPadding, y: CodeViewConfiguration.barPadding),
                size: labelSize
            )
        }

        private func layoutLineNumberView(barHeight: CGFloat) {
            let lineNumberSize = lineNumberView.intrinsicContentSize
            lineNumberView.frame = CGRect(
                x: 0,
                y: barHeight,
                width: lineNumberSize.width,
                height: bounds.height - barHeight
            )
        }

        private func layoutScrollViewAndTextView(barHeight: CGFloat) {
            let textContentSize = textView.intrinsicContentSize
            let lineNumberWidth = lineNumberView.intrinsicContentSize.width

            scrollView.frame = CGRect(
                x: lineNumberWidth,
                y: barHeight,
                width: bounds.width - lineNumberWidth,
                height: bounds.height - barHeight
            )

            textView.frame = CGRect(
                x: 0,
                y: 0,
                width: max(scrollView.bounds.width - CodeViewConfiguration.codePadding * 2, textContentSize.width),
                height: textContentSize.height
            )
        }
    }
#endif
