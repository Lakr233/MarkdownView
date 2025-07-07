//
//  TestDocuments.swift
//  Example
//
//  Created by 秋星桥 on 7/8/25.
//

import Foundation
import markdown_core
import markdown_core_ast

func ast_parse_paragraph() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    Hello world
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_heading() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    # Heading 1
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_thematicBreak() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    ---
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_blockquote() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    > quote
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_list() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    - item1
    - item2
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_listItem() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    - item1
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_html() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    <div>html</div>
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_code() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    ```swift
    let a = 1
    ```
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_definition() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    [foo]: /url "title"
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_text() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    Nulla incididunt eu amet dolore ad quis consequat in et aliqua nisi mollit nostrud ex. Irure est est laborum Lorem sunt pariatur laborum adipisicing proident deserunt deserunt. Non ipsum tempor est ea ullamco amet labore ex excepteur nisi id adipisicing aute anim. Mollit incididunt consectetur esse ipsum irure consectetur sunt magna ut. Ad duis veniam nulla do id veniam non officia do magna eiusmod ut sunt cupidatat veniam.
    Nulla incididunt eu amet dolore ad quis consequat in et aliqua nisi mollit nostrud ex. Irure est est laborum Lorem sunt pariatur laborum adipisicing proident deserunt deserunt. Non ipsum tempor est ea ullamco amet labore ex excepteur nisi id adipisicing aute anim. Mollit incididunt consectetur esse ipsum irure consectetur sunt magna ut. Ad duis veniam nulla do id veniam non officia do magna eiusmod ut sunt cupidatat veniam.
    Nulla incididunt eu amet dolore ad quis consequat in et aliqua nisi mollit nostrud ex. Irure est est laborum Lorem sunt pariatur laborum adipisicing proident deserunt deserunt. Non ipsum tempor est ea ullamco amet labore ex excepteur nisi id adipisicing aute anim. Mollit incididunt consectetur esse ipsum irure consectetur sunt magna ut. Ad duis veniam nulla do id veniam non officia do magna eiusmod ut sunt cupidatat veniam.Nulla incididunt eu amet dolore ad quis consequat in et aliqua nisi mollit nostrud ex. Irure est est laborum Lorem sunt pariatur laborum adipisicing proident deserunt deserunt. Non ipsum tempor est ea ullamco amet labore ex excepteur nisi id adipisicing aute anim. Mollit incididunt consectetur esse ipsum irure consectetur sunt magna ut. Ad duis veniam nulla do id veniam non officia do magna eiusmod ut sunt cupidatat veniam.Nulla incididunt eu amet dolore ad quis consequat in et aliqua nisi mollit nostrud ex. Irure est est laborum Lorem sunt pariatur laborum adipisicing proident deserunt deserunt. Non ipsum tempor est ea ullamco amet labore ex excepteur nisi id adipisicing aute anim. Mollit incididunt consectetur esse ipsum irure consectetur sunt magna ut. Ad duis veniam nulla do id veniam non officia do magna eiusmod ut sunt cupidatat veniam.
    Nulla incididunt eu amet dolore ad quis consequat in et aliqua nisi mollit nostrud ex. Irure est est laborum Lorem sunt pariatur laborum adipisicing proident deserunt deserunt. Non ipsum tempor est ea ullamco amet labore ex excepteur nisi id adipisicing aute anim. Mollit incididunt consectetur esse ipsum irure consectetur sunt magna ut. Ad duis veniam nulla do id veniam non officia do magna eiusmod ut sunt cupidatat veniam.
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_emphasis() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    *em*
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_strong() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    **Nulla enim non labore quis excepteur et officia sunt ea ipsum voluptate consectetur aliqua ipsum anim. Excepteur labore officia esse consequat amet ipsum fugiat mollit ut duis id quis. Ex id et incididunt proident nostrud. Anim cillum ipsum irure nostrud ut pariatur dolor esse. Consectetur Lorem mollit aute eiusmod aliquip Lorem minim ipsum in ullamco amet est amet.**
    **Non labore consectetur non commodo reprehenderit.**
    **Mollit amet eu ullamco qui in fugiat cillum ea elit laborum irure id. Labore et laborum proident quis Lorem excepteur. Qui dolor ex irure elit occaecat anim nisi proident adipisicing est elit cillum reprehenderit. Esse quis Lorem veniam cupidatat minim voluptate duis nostrud adipisicing occaecat anim occaecat officia occaecat commodo. Tempor dolor cupidatat incididunt eu reprehenderit labore cillum ullamco occaecat.**
    **Irure et aute proident consectetur in quis ea deserunt deserunt ea deserunt amet cillum. Est consectetur officia non aute velit tempor magna minim ad. Amet consequat sunt tempor pariatur esse. Consectetur anim duis proident exercitation cillum minim et occaecat dolor veniam.**
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_inlineCode() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    `code`
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_break() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    line  
    break
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_link() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    [link](url)
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_image() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    ![alt](url)
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_linkReference() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    [foo][bar]

    [bar]: /url
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_imageReference() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    ![alt][bar]

    [bar]: /url
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_delete() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    ~~del~~
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_footnoteDefinition() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    [^1]: footnote
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_footnoteReference() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    footnote[^1]

    [^1]: footnote
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_table() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    | a | b |
    |---|---|
    | 1 | 2 |
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_tableRow() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    | a | b |
    |---|---|
    | 1 | 2 |
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_tableCell() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    | a | b |
    |---|---|
    | 1 | 2 |
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_math() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    $$
    x+1
    $$
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}

func ast_parse_inlineMath() -> Root {
    let json = markdown_rs_core_parse_to_ast_json(###"""
    $x+1$
    """###)
    let ast = try! MarkdownAbstractSyntaxTreeParser.parse(from: json)
    return ast
}
