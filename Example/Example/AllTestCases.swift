//
//  AllTestCases.swift
//  Example
//
//  Created by 秋星桥 on 7/8/25.
//

import Foundation
import markdown_core
import markdown_core_ast

enum AllTestCases: CaseIterable {
    case root
    case blockquote
    case breakNode
    case code
    case definition
    case delete
    case emphasis
    case footnoteDefinition
    case footnoteReference
    case heading
    case html
    case image
    case imageReference
    case inlineCode
    case inlineMath
    case link
    case linkReference
    case list
    case listItem
    case math
    case paragraph
    case strong
    case table
    case tableCell
    case tableRow
    case text
    case thematicBreak

    static var allCases: [AllTestCases] {
        [
            .root,
            .blockquote,
            .breakNode,
            .code,
            .definition,
            .delete,
            .emphasis,
            .footnoteDefinition,
            .footnoteReference,
            .heading,
            .html,
            .image,
            .imageReference,
            .inlineCode,
            .inlineMath,
            .link,
            .linkReference,
            .list,
            .listItem,
            .math,
            .paragraph,
            .strong,
            .table,
            .tableCell,
            .tableRow,
            .text,
            .thematicBreak,
        ]
    }

    func createTestableAstNode() -> Root {
        switch self {
        case .root:
            ast_parse_large()
        case .blockquote:
            ast_parse_blockquote()
        case .breakNode:
            ast_parse_break()
        case .code:
            ast_parse_code()
        case .definition:
            ast_parse_definition()
        case .delete:
            ast_parse_delete()
        case .emphasis:
            ast_parse_emphasis()
        case .footnoteDefinition:
            ast_parse_footnoteDefinition()
        case .footnoteReference:
            ast_parse_footnoteReference()
        case .heading:
            ast_parse_heading()
        case .html:
            ast_parse_html()
        case .image:
            ast_parse_image()
        case .imageReference:
            ast_parse_imageReference()
        case .inlineCode:
            ast_parse_inlineCode()
        case .inlineMath:
            ast_parse_inlineMath()
        case .link:
            ast_parse_link()
        case .linkReference:
            ast_parse_linkReference()
        case .list:
            ast_parse_list()
        case .listItem:
            ast_parse_listItem()
        case .math:
            ast_parse_math()
        case .paragraph:
            ast_parse_paragraph()
        case .strong:
            ast_parse_strong()
        case .table:
            ast_parse_table()
        case .tableCell:
            ast_parse_tableCell()
        case .tableRow:
            ast_parse_tableRow()
        case .text:
            ast_parse_text()
        case .thematicBreak:
            ast_parse_thematicBreak()
        }
    }
}
