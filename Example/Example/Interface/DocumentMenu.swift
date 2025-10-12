//
//  DocumentMenu.swift
//  Example
//
//  Created by 秋星桥 on 6/29/25.
//

import Foundation
import MarkdownParser

enum DocumentMenu {
    static let sections = [
        DocumentSection(
            title: "📝 数学与教育",
            description: "数学公式、方程解法和教育内容测试",
            documents: [
                DocumentItem(title: "方程解法详解", document: mathEquationsDocument),
                DocumentItem(title: "几何与代数", document: geometryAlgebraDocument),
                DocumentItem(title: "解题技巧总结", document: problemSolvingTipsDocument),
            ]
        ),
        DocumentSection(
            title: "💬 引用与段落",
            description: "各种引用格式和段落样式测试",
            documents: [
                DocumentItem(title: "基础引用测试", document: basicBlockquotesDocument),
                DocumentItem(title: "嵌套引用测试", document: nestedBlockquotesDocument),
                DocumentItem(title: "带格式的引用", document: formattedBlockquotesDocument),
            ]
        ),
        DocumentSection(
            title: "📋 列表与表格",
            description: "列表、表格和结构化内容测试",
            documents: [
                DocumentItem(title: "多层嵌套列表", document: nestedListsDocument),
                DocumentItem(title: "数据表格", document: dataTablesDocument),
                DocumentItem(title: "任务列表", document: todoListsDocument),
            ]
        ),
        DocumentSection(
            title: "⌨️ 代码与技术",
            description: "代码块和编程相关内容",
            documents: [
                DocumentItem(title: "Python代码示例", document: pythonCodeDocument),
                DocumentItem(title: "多行乘法教学", document: multiplicationExampleDocument),
            ]
        ),
        DocumentSection(
            title: "🚀 iOS开发",
            description: "iOS开发相关文档",
            documents: [
                DocumentItem(title: "SceneDelegate配置", document: sceneDelegateDocument),
            ]
        ),
    ]
}

struct DocumentSection {
    let title: String
    let description: String
    let documents: [DocumentItem]
}

struct DocumentItem {
    let title: String
    let document: String
}
