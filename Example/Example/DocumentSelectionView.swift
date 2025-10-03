//
//  DocumentSelectionView.swift
//  Example
//
//  Created by 秋星桥 on 6/29/25.
//

import MarkdownParser
import MarkdownView
import SwiftUI

struct DocumentSelectionView: View {
    @State private var selectedDocument: DocumentItem? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(DocumentMenu.sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.documents, id: \.title) { documentItem in
                            NavigationLink(destination: DocumentDisplayView(document: documentItem.document, title: documentItem.title)) {
                                Text(documentItem.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("文档选择")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct DocumentDisplayView: View {
    let document: String
    let title: String

    var body: some View {
        MarkdownContentView(document: document)
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct MarkdownContentView: UIViewRepresentable {
    let document: String

    func makeUIView(context: Context) -> MarkdownTextView {
        let textView = MarkdownTextView()
        updateUIView(textView, context: context)
        return textView
    }

    func updateUIView(_ uiView: MarkdownTextView, context _: Context) {
        let parser = MarkdownParser()
        let result = parser.parse(document)
        let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: .default)
        uiView.setMarkdown(content)
    }
}
