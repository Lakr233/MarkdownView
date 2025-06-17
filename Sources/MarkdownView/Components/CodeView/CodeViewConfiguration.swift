//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import UIKit

enum CodeViewConfiguration {
    static let barPadding: CGFloat = 8
    static let codePadding: CGFloat = 8
    static let codeLineSpacing: CGFloat = 6

    static func intrinsicHeight(
        for content: String,
        theme: MarkdownTheme = .default
    ) -> CGFloat {
        let font = theme.fonts.code
        let lineHeight = font.lineHeight
        let barHeight = lineHeight + barPadding * 2
        let numberOfRows = content.components(separatedBy: .newlines).count
        let codeHeight = lineHeight * CGFloat(numberOfRows)
            + codePadding * 2
            + codeLineSpacing * CGFloat(max(numberOfRows - 1, 0))
        return ceil(barHeight + codeHeight)
    }
}

extension CodeView {
    func configureSubviews() {
        setupViewAppearance()
        setupBarView()
        setupButtons()
        setupScrollView()
        setupTextView()
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
        scrollView.addSubview(textView)
    }

    func performLayout() {
        let labelSize = languageLabel.intrinsicContentSize
        let barHeight = max(languageLabel.font.lineHeight, labelSize.height) + CodeViewConfiguration.barPadding * 2

        layoutBarView(barHeight: barHeight, labelSize: labelSize)
        layoutButtons()
        layoutScrollViewAndTextView(barHeight: barHeight)
    }

    private func layoutButtons() {
        let buttonSize = CGSize(width: 44, height: 44)
        let hasPreview = previewAction != nil

        if hasPreview {
            // 如果有预览按钮，复制按钮在右边，预览按钮在左边
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
            // 如果没有预览按钮，复制按钮直接靠右
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

    private func layoutScrollViewAndTextView(barHeight: CGFloat) {
        let textContentSize = textView.intrinsicContentSize

        scrollView.frame = CGRect(
            x: 0,
            y: barHeight,
            width: bounds.width,
            height: bounds.height - barHeight
        )

        textView.frame = CGRect(
            x: CodeViewConfiguration.codePadding,
            y: CodeViewConfiguration.codePadding,
            width: max(bounds.width - CodeViewConfiguration.codePadding * 2, textContentSize.width),
            height: textContentSize.height
        )

        scrollView.contentSize = CGSize(
            width: textView.frame.width + CodeViewConfiguration.codePadding * 2,
            height: 0 // disable vertical scrolling to fix rarer bug
        )
    }
}
