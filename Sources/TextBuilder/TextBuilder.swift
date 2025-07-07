//
//  TextBuilder.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/7/25.
//

import markdown_core
import markdown_core_ast
import UIKit

public class TextBuilder {
    let theme: MarkdownTheme

    init(theme: MarkdownTheme) {
        self.theme = theme
    }

    func parse(_ document: String) throws -> Root {
        try MarkdownAbstractSyntaxTreeParser.parse(
            from: markdown_rs_core_parse_to_ast_json(document)
        )
    }

    func build(_ document: String) throws -> NSAttributedString {
        try build(parse(document))
    }

    func build(_ ast: Root) -> NSAttributedString {
        let build = NSMutableAttributedString()
        for child in ast.children {
            let transformer = child.transformer
            let attributedString = transformer.transform(child, theme: theme)
            if !attributedString.string.isEmpty {
                build.append(attributedString)
            }
        }
        return build
    }
}
