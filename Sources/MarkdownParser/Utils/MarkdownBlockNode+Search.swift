import Foundation

extension [MarkdownBlockNode] {
    /// Whether any text node, at any depth, satisfies `predicate`.
    func containsText(where predicate: (String) -> Bool) -> Bool {
        contains { $0.containsText(where: predicate) }
    }

    /// Whether any code block, at any depth, has content satisfying `predicate`.
    func containsCodeBlock(where predicate: (String) -> Bool) -> Bool {
        contains { $0.containsCodeBlock(where: predicate) }
    }
}

extension MarkdownBlockNode {
    func containsText(where predicate: (String) -> Bool) -> Bool {
        switch self {
        case let .blockquote(children):
            children.containsText(where: predicate)
        case let .bulletedList(_, items), let .numberedList(_, _, items):
            items.contains { $0.children.containsText(where: predicate) }
        case let .taskList(_, items):
            items.contains { $0.children.containsText(where: predicate) }
        case let .paragraph(content), let .heading(_, content):
            content.containsText(where: predicate)
        case let .table(_, rows):
            rows.contains { row in
                row.cells.contains { $0.content.containsText(where: predicate) }
            }
        case .codeBlock, .thematicBreak:
            false
        }
    }

    func containsCodeBlock(where predicate: (String) -> Bool) -> Bool {
        switch self {
        case let .codeBlock(_, content):
            predicate(content)
        case let .blockquote(children):
            children.containsCodeBlock(where: predicate)
        case let .bulletedList(_, items), let .numberedList(_, _, items):
            items.contains { $0.children.containsCodeBlock(where: predicate) }
        case let .taskList(_, items):
            items.contains { $0.children.containsCodeBlock(where: predicate) }
        case .paragraph, .heading, .table, .thematicBreak:
            false
        }
    }
}

extension [MarkdownInlineNode] {
    func containsText(where predicate: (String) -> Bool) -> Bool {
        contains { node in
            if case let .text(text) = node {
                return predicate(text)
            }
            return node.children.containsText(where: predicate)
        }
    }
}

extension String {
    /// Whether the UTF-8 bytes of `needle` occur in this string's bytes.
    ///
    /// A byte search, so it never misses a match `contains` would find for an
    /// ASCII needle; it only skips Unicode-aware comparison.
    func utf8Contains(_ needle: StaticString) -> Bool {
        var haystack = self
        return haystack.withUTF8 { haystack in
            needle.withUTF8Buffer { needle in
                guard needle.count <= haystack.count else { return false }
                guard let haystackBase = haystack.baseAddress, let needleBase = needle.baseAddress else {
                    return needle.isEmpty
                }
                return memmem(haystackBase, haystack.count, needleBase, needle.count) != nil
            }
        }
    }
}
