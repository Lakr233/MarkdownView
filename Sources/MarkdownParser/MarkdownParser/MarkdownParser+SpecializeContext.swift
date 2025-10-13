//
//  MarkdownParser+SpecializeContext.swift
//  MarkdownView
//
//  Created by 秋星桥 on 5/27/25.
//

import cmark_gfm
import cmark_gfm_extensions
import Foundation

extension MarkdownParser {
    class SpecializeContext {
        private var context: [MarkdownBlockNode] = []

        init() {}

        func append(_ node: MarkdownBlockNode) {
            context.append(contentsOf: normalize(node))
        }

        func complete() -> [MarkdownBlockNode] {
            defer { context.removeAll() }
            return context
        }
    }
}

private extension MarkdownParser.SpecializeContext {
    func normalize(_ node: MarkdownBlockNode) -> [MarkdownBlockNode] {
        switch node {
        case let .blockquote(children):
            let flattenedChildren = normalizeBlockquote(children: children)
            return [.blockquote(children: flattenedChildren)]
        case let .bulletedList(isTight, items):
            return normalizeBulletedList(isTight: isTight, items: items)
        case let .numberedList(isTight, start, items):
            return normalizeNumberedList(isTight: isTight, start: start, items: items)
        case let .taskList(isTight, items):
            return normalizeTaskList(isTight: isTight, items: items)
        default:
            return [node]
        }
    }

    func normalizeBlockquote(children: [MarkdownBlockNode]) -> [MarkdownBlockNode] {
        collectParagraphs(from: children)
    }

    func normalizeBulletedList(isTight: Bool, items: [RawListItem]) -> [MarkdownBlockNode] {
        let normalizedItems = items.map { normalize(rawItem: $0) }
        return assembleList(normalizedItems: normalizedItems) { processed in
            .bulletedList(isTight: isTight, items: processed)
        }
    }

    func normalizeNumberedList(isTight: Bool, start: Int, items: [RawListItem]) -> [MarkdownBlockNode] {
        let normalizedItems = items.map { normalize(rawItem: $0) }
        let shouldDowngrade = normalizedItems.contains { !$0.lifted.isEmpty }
        return assembleList(normalizedItems: normalizedItems) { processed in
            if shouldDowngrade {
                .bulletedList(isTight: isTight, items: processed)
            } else {
                .numberedList(isTight: isTight, start: start, items: processed)
            }
        }
    }

    func normalizeTaskList(isTight: Bool, items: [RawTaskListItem]) -> [MarkdownBlockNode] {
        let normalizedItems = items.map { normalize(taskItem: $0) }
        return assembleList(normalizedItems: normalizedItems) { processed in
            .taskList(isTight: isTight, items: processed)
        }
    }

    func assembleList<Item>(
        normalizedItems: [ListItemNormalization<Item>],
        makeList: ([Item]) -> MarkdownBlockNode
    ) -> [MarkdownBlockNode] {
        var result: [MarkdownBlockNode] = []
        var pendingItems: [Item] = []

        for normalized in normalizedItems {
            pendingItems.append(normalized.item)

            if !normalized.lifted.isEmpty {
                if !pendingItems.isEmpty {
                    result.append(makeList(pendingItems))
                    pendingItems.removeAll(keepingCapacity: true)
                }
                result.append(contentsOf: normalized.lifted)
            }
        }

        if !pendingItems.isEmpty {
            result.append(makeList(pendingItems))
        }

        return result
    }

    func normalize(rawItem: RawListItem) -> ListItemNormalization<RawListItem> {
        let (retained, lifted) = partitionListChildren(rawItem.children)
        return .init(item: RawListItem(children: retained), lifted: lifted)
    }

    func normalize(taskItem: RawTaskListItem) -> ListItemNormalization<RawTaskListItem> {
        let (retained, lifted) = partitionListChildren(taskItem.children)
        return .init(item: RawTaskListItem(isCompleted: taskItem.isCompleted, children: retained), lifted: lifted)
    }

    func partitionListChildren(_ children: [MarkdownBlockNode]) -> (retained: [MarkdownBlockNode], lifted: [MarkdownBlockNode]) {
        var retained: [MarkdownBlockNode] = []
        var lifted: [MarkdownBlockNode] = []

        for child in children {
            let normalizedChildren = normalize(child)
            for normalizedChild in normalizedChildren {
                if shouldLiftFromList(normalizedChild) {
                    lifted.append(normalizedChild)
                } else {
                    retained.append(normalizedChild)
                }
            }
        }

        return (retained, lifted)
    }

    func shouldLiftFromList(_ node: MarkdownBlockNode) -> Bool {
        // These block-level nodes break list continuity and must be promoted alongside the list.
        switch node {
        case .blockquote, .codeBlock, .table, .heading, .thematicBreak:
            true
        default:
            false
        }
    }

    func collectParagraphs(from nodes: [MarkdownBlockNode]) -> [MarkdownBlockNode] {
        var paragraphs: [MarkdownBlockNode] = []

        for node in nodes {
            switch node {
            case let .paragraph(content):
                paragraphs.append(.paragraph(content: content))
            case let .heading(_, content):
                paragraphs.append(.paragraph(content: content))
            case let .codeBlock(_, content):
                paragraphs.append(.paragraph(content: [.text(content)]))
            case let .blockquote(children):
                let nested = collectParagraphs(from: children)
                paragraphs.append(contentsOf: nested)
            case let .bulletedList(_, items):
                for item in items {
                    let nested = collectParagraphs(from: item.children)
                    paragraphs.append(contentsOf: nested)
                }
            case let .numberedList(_, _, items):
                for item in items {
                    let nested = collectParagraphs(from: item.children)
                    paragraphs.append(contentsOf: nested)
                }
            case let .taskList(_, items):
                for item in items {
                    let nested = collectParagraphs(from: item.children)
                    paragraphs.append(contentsOf: nested)
                }
            case let .table(_, rows):
                for row in rows {
                    for cell in row.cells {
                        paragraphs.append(.paragraph(content: cell.content))
                    }
                }
            case .thematicBreak:
                continue
            }
        }

        return paragraphs
    }

    struct ListItemNormalization<Item> {
        let item: Item
        let lifted: [MarkdownBlockNode]
    }
}
