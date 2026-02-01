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

enum CodeViewConfiguration {
    static let barPadding: CGFloat = 8
    static let codePadding: CGFloat = 8
    static let codeLineSpacing: CGFloat = 4
    static let lineNumberWidth: CGFloat = 40
    static let lineNumberPadding: CGFloat = 8

    static func intrinsicHeight(
        for content: String,
        theme: MarkdownTheme = .default
    ) -> CGFloat {
        let font = theme.fonts.code
        #if canImport(UIKit)
            let lineHeight = font.lineHeight
        #elseif canImport(AppKit)
            let lineHeight = font.ascender + abs(font.descender) + font.leading
        #endif
        let barHeight = lineHeight + barPadding * 2
        let numberOfRows = content.components(separatedBy: .newlines).count
        let codeHeight = lineHeight * CGFloat(numberOfRows)
            + codePadding * 2
            + codeLineSpacing * CGFloat(max(numberOfRows - 1, 0))
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
            clipsToBounds = true
            backgroundColor = .gray.withAlphaComponent(0.05)
        }

        private func setupBarView() {
            barView.backgroundColor = .gray.withAlphaComponent(0.05)
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
            previewButton.addTarget(self, action: #selector(handlePreview(_:)), for: .touchUpInside)
            barView.addSubview(previewButton)
        }

        private func setupCopyButton() {
            let copyImage = UIImage(
                systemName: "doc.on.doc",
                withConfiguration: UIImage.SymbolConfiguration(scale: .small)
            )
            copyButton.setImage(copyImage, for: .normal)
            copyButton.addTarget(self, action: #selector(handleCopy(_:)), for: .touchUpInside)
            barView.addSubview(copyButton)
        }

        private func setupScrollView() {
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.alwaysBounceVertical = false
            scrollView.alwaysBounceHorizontal = false
            addSubview(scrollView)
        }

        private func setupTextView() {
            textView.backgroundColor = .clear
            textView.preferredMaxLayoutWidth = .infinity
            textView.isSelectable = true
            textView.selectionBackgroundColor = theme.colors.selectionBackground
            scrollView.addSubview(textView)
        }

        private func setupLineNumberView() {
            lineNumberView.backgroundColor = .clear
            addSubview(lineNumberView)
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

        private func layoutButtons() {
            let buttonSize = CGSize(width: 44, height: 44)
            let hasPreview = previewAction != nil

            if hasPreview {
                copyButton.frame = CGRect(
                    x: barView.bounds.width - buttonSize.width,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
                previewButton.isHidden = false
                previewButton.frame = CGRect(
                    x: copyButton.frame.minX - buttonSize.width,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
            } else {
                copyButton.frame = CGRect(
                    x: barView.bounds.width - buttonSize.width,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
                previewButton.isHidden = true
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
            barView.addSubview(previewButton)
        }

        private func setupCopyButton() {
            if let copyImage = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil) {
                copyButton.image = copyImage
            }
            copyButton.target = self
            copyButton.action = #selector(handleCopy(_:))
            copyButton.bezelStyle = .inline
            copyButton.isBordered = false
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
            textView.preferredMaxLayoutWidth = .infinity
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

        private func layoutButtons() {
            let buttonSize = CGSize(width: 44, height: 44)
            let hasPreview = previewAction != nil

            if hasPreview {
                copyButton.frame = CGRect(
                    x: barView.bounds.width - buttonSize.width,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
                previewButton.isHidden = false
                previewButton.frame = CGRect(
                    x: copyButton.frame.minX - buttonSize.width,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
            } else {
                copyButton.frame = CGRect(
                    x: barView.bounds.width - buttonSize.width,
                    y: (barView.bounds.height - buttonSize.height) / 2,
                    width: buttonSize.width,
                    height: buttonSize.height
                )
                previewButton.isHidden = true
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
