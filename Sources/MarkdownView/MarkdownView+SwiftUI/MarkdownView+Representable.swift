//
//  MarkdownView+Representable.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit

    struct MarkdownViewRepresentable: UIViewRepresentable, MarkdownViewRepresentableBase {
        let contentSource: MarkdownView.ContentSource
        let theme: MarkdownTheme
        @Binding var measuredHeight: CGFloat

        var heightBinding: Binding<CGFloat> {
            $measuredHeight
        }

        func makeUIView(context _: Context) -> MarkdownTextView {
            createMarkdownTextView()
        }

        func updateUIView(_ uiView: MarkdownTextView, context: Context) {
            updateMarkdownTextView(uiView, coordinator: context.coordinator)
        }

        func sizeThatFits(
            _ proposal: ProposedViewSize,
            uiView: MarkdownTextView,
            context: Context
        ) -> CGSize? {
            context.coordinator.sizeThatFits(proposal, for: uiView)
        }

        func makeCoordinator() -> MarkdownViewCoordinator {
            MarkdownViewCoordinator()
        }
    }

#elseif canImport(AppKit)
    import AppKit

    struct MarkdownViewRepresentable: NSViewRepresentable, MarkdownViewRepresentableBase {
        let contentSource: MarkdownView.ContentSource
        let theme: MarkdownTheme
        @Binding var measuredHeight: CGFloat

        var heightBinding: Binding<CGFloat> {
            $measuredHeight
        }

        func makeNSView(context _: Context) -> MarkdownTextView {
            createMarkdownTextView()
        }

        func updateNSView(_ nsView: MarkdownTextView, context: Context) {
            updateMarkdownTextView(nsView, coordinator: context.coordinator)
        }

        func sizeThatFits(
            _ proposal: ProposedViewSize,
            nsView: MarkdownTextView,
            context: Context
        ) -> CGSize? {
            context.coordinator.sizeThatFits(proposal, for: nsView)
        }

        func makeCoordinator() -> MarkdownViewCoordinator {
            MarkdownViewCoordinator()
        }
    }
#endif
