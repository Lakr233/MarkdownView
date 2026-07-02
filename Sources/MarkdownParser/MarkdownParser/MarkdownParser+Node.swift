//
//  MarkdownParser+Node.swift
//  FlowMarkdownView
//
//  Created by 秋星桥 on 2025/1/3.
//

import cmark_gfm
import cmark_gfm_extensions
import Foundation

extension MarkdownParser {
    func dumpBlocks(root: UnsafeNode?, mathContext: MathContext) -> [MarkdownBlockNode] {
        guard let root else {
            assertionFailure()
            return []
        }
        assert(root.pointee.type == CMARK_NODE_DOCUMENT.rawValue)
        let nodeList = root.children
            .compactMap(MarkdownBlockNode.init(unsafeNode:))
            .rewrite { node -> [MarkdownBlockNode] in
                guard case let .codeBlock(language, content) = node else {
                    return [node]
                }
                return [.codeBlock(fenceInfo: language, content: mathContext.restore(content: content))]
            }

        let reorderContext = SpecializeContext()
        for node in nodeList {
            reorderContext.append(node)
        }
        return reorderContext.complete()
    }
}
