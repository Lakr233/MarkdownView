//
//  MarkdownTextView+ContextViewLayout.swift
//  MarkdownView
//
//  Created by Codex on 7/3/26.
//

import Foundation
import Litext

#if canImport(UIKit)
    import UIKit

    extension MarkdownTextView {
        func syncContextViewLayout() {
            for run in textLabelView.layoutRuns(matching: .contextView) {
                if let codeView = run.attributes[.contextView] as? CodeView {
                    syncCodeView(codeView, with: run)
                    continue
                }

                if let tableView = run.attributes[.contextView] as? TableView {
                    syncTableView(tableView, with: run)
                }
            }
        }

        private func syncCodeView(_ codeView: CodeView, with run: TextLabel.LayoutRun) {
            if codeView.superview != self {
                addSubview(codeView)
            }
            codeView.textView.delegate = self
            codeView.previewAction = codePreviewHandler
            setFrameIfNeeded(
                for: codeView,
                to: contextViewFrame(for: run, height: codeView.intrinsicContentSize.height)
            )
        }

        private func syncTableView(_ tableView: TableView, with run: TextLabel.LayoutRun) {
            if tableView.superview != self {
                addSubview(tableView)
            }
            tableView.linkHandler = linkHandler
            tableView.textSelectionDelegate = self
            setFrameIfNeeded(
                for: tableView,
                to: contextViewFrame(for: run, height: tableView.intrinsicContentSize.height)
            )
        }

        private func contextViewFrame(for run: TextLabel.LayoutRun, height: CGFloat) -> CGRect {
            let leftIndent = paragraphHeadIndent(in: run.attributes)
            return CGRect(
                x: textLabelView.frame.minX + run.lineRect.minX + leftIndent,
                y: textLabelView.frame.minY + textLabelView.bounds.height - run.lineRect.maxY,
                width: max(0, textLabelView.bounds.width - leftIndent),
                height: height
            )
        }

        private func paragraphHeadIndent(in attributes: [NSAttributedString.Key: Any]) -> CGFloat {
            guard let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle else {
                return 0
            }
            return paragraphStyle.headIndent
        }

        private func setFrameIfNeeded(for view: UIView, to frame: CGRect) {
            guard view.frame != frame else { return }
            view.frame = frame
        }
    }

#elseif canImport(AppKit)
    import AppKit

    extension MarkdownTextView {
        func syncContextViewLayout() {
            for run in textLabelView.layoutRuns(matching: .contextView) {
                if let codeView = run.attributes[.contextView] as? CodeView {
                    syncCodeView(codeView, with: run)
                    continue
                }

                if let tableView = run.attributes[.contextView] as? TableView {
                    syncTableView(tableView, with: run)
                }
            }
        }

        private func syncCodeView(_ codeView: CodeView, with run: TextLabel.LayoutRun) {
            if codeView.superview != self {
                addSubview(codeView)
            }
            codeView.textView.delegate = self
            codeView.previewAction = codePreviewHandler
            setFrameIfNeeded(
                for: codeView,
                to: contextViewFrame(for: run, height: codeView.intrinsicContentSize.height)
            )
        }

        private func syncTableView(_ tableView: TableView, with run: TextLabel.LayoutRun) {
            if tableView.superview != self {
                addSubview(tableView)
            }
            tableView.linkHandler = linkHandler
            tableView.textSelectionDelegate = self
            setFrameIfNeeded(
                for: tableView,
                to: contextViewFrame(for: run, height: tableView.intrinsicContentSize.height)
            )
        }

        private func contextViewFrame(for run: TextLabel.LayoutRun, height: CGFloat) -> CGRect {
            let leftIndent = paragraphHeadIndent(in: run.attributes)
            return CGRect(
                x: textLabelView.frame.minX + run.lineRect.minX + leftIndent,
                y: textLabelView.frame.minY + textLabelView.bounds.height - run.lineRect.maxY,
                width: max(0, textLabelView.bounds.width - leftIndent),
                height: height
            )
        }

        private func paragraphHeadIndent(in attributes: [NSAttributedString.Key: Any]) -> CGFloat {
            guard let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle else {
                return 0
            }
            return paragraphStyle.headIndent
        }

        private func setFrameIfNeeded(for view: NSView, to frame: CGRect) {
            guard view.frame != frame else { return }
            view.frame = frame
        }
    }
#endif
