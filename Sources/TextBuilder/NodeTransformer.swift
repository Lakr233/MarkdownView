//
//  NodeTransformer.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

protocol NodeTransformer {
    func transform(_ input: NodeWrapper, theme: MarkdownTheme) -> NSAttributedString
    func transform(children: [NodeWrapper], theme: MarkdownTheme) -> NSAttributedString
}

extension NodeTransformer {
    func transform(children: [NodeWrapper], theme: MarkdownTheme) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in children {
            let transformer = child.transformer
            let attributedString = transformer.transform(child, theme: theme)
            result.append(attributedString)
        }
        return result
    }
}

extension NodeWrapper {
    var transformer: NodeTransformer {
        switch self {
        case .blockquote: TextBuilderForBlockquote.shared
        case .breakNode: TextBuilderForBreak.shared
        case .code: TextBuilderForCode.shared
        case .definition: TextBuilderForDefinition.shared
        case .delete: TextBuilderForDelete.shared
        case .emphasis: TextBuilderForEmphasis.shared
        case .footnoteDefinition: TextBuilderForFootnoteDefinition.shared
        case .footnoteReference: TextBuilderForFootnoteReference.shared
        case .heading: TextBuilderForHeading.shared
        case .html: TextBuilderForHtml.shared
        case .image: TextBuilderForImage.shared
        case .imageReference: TextBuilderForImageReference.shared
        case .inlineCode: TextBuilderForInlineCode.shared
        case .inlineMath: TextBuilderForInlineMath.shared
        case .link: TextBuilderForLink.shared
        case .linkReference: TextBuilderForLinkReference.shared
        case .list: TextBuilderForList.shared
        case .listItem: TextBuilderForListItem.shared
        case .math: TextBuilderForMath.shared
        case .paragraph: TextBuilderForParagraph.shared
        case .root: TextBuilderForRoot.shared
        case .strong: TextBuilderForStrong.shared
        case .table: TextBuilderForTable.shared
        case .tableCell: TextBuilderForTableCell.shared
        case .tableRow: TextBuilderForTableRow.shared
        case .text: TextBuilderForText.shared
        case .thematicBreak: TextBuilderForThematicBreak.shared
        }
    }

    func createDefaultAttributedString(text: String, theme: MarkdownTheme) -> NSMutableAttributedString {
        let attributes = createDefaultAttributes(theme: theme)
        return NSMutableAttributedString(string: text, attributes: attributes)
    }

    func createDefaultAttributes(theme: MarkdownTheme) -> [NSAttributedString.Key: Any] {
        [
            .font: theme.fonts.body,
            .foregroundColor: theme.colors.body,
            .paragraphStyle: createDefaultParagraphStyle(theme: theme),
        ]
    }

    func createDefaultParagraphStyle(theme: MarkdownTheme) -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.spacings.general
        paragraphStyle.paragraphSpacing = theme.spacings.final
        paragraphStyle.lineBreakMode = .byWordWrapping
        return paragraphStyle
    }

    func insertNewline(into: NSMutableAttributedString, theme: MarkdownTheme) {
        let newline = NSAttributedString(
            string: "\n",
            attributes: createDefaultAttributes(theme: theme)
        )
        into.append(newline)
    }
}
