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
            // A container with no width lays out no runs, and hiding every
            // context view against that empty layout blanks them until a later
            // pass happens to re-place them. Keep whatever a previous pass
            // placed until the container has a size again.
            guard textLabelView.bounds.width > 0 else { return }

            var placed: Set<PlatformView> = []
            var runCount = 0

            for run in textLabelView.layoutRuns(matching: .contextView) {
                runCount += 1
                if let codeView = run.attributes[.contextView] as? CodeView {
                    syncCodeView(codeView, with: run)
                    placed.insert(codeView)
                    continue
                }

                if let tableView = run.attributes[.contextView] as? TableView {
                    syncTableView(tableView, with: run)
                    placed.insert(tableView)
                }
            }

            // A view whose line did not survive this layout pass has no known
            // position, and its previous frame belongs to a layout that no longer
            // exists. Hide it rather than let it paint over the text — but only
            // once this pass actually saw runs. A rebuild caught before the text
            // layout produced any would otherwise hide every block and blank it
            // until a later, unrelated layout pass puts it back.
            if runCount > 0 || contextViews.isEmpty {
                for view in contextViews {
                    view.isHidden = !placed.contains(view)
                }
            }

            syncBlockquoteBars()
        }

        /// Gives every blockquote a bar spanning all of its lines.
        ///
        /// The bar is a view instead of a line drawing action because an action
        /// only runs for the lines a redraw touches, which paints a bar spanning
        /// several lines in fragments.
        private func syncBlockquoteBars() {
            let spans = blockquoteLineSpans()

            while blockquoteBars.count < spans.count {
                let bar = BlockquoteBarView()
                blockquoteBars.append(bar)
                addSubview(bar)
            }
            while blockquoteBars.count > spans.count {
                blockquoteBars.removeLast().removeFromSuperview()
            }

            for (bar, span) in zip(blockquoteBars, spans) {
                bar.setTheme(theme)
                bar.isHidden = false
                setFrameIfNeeded(for: bar, to: span)
            }
        }

        private func syncCodeView(_ codeView: CodeView, with run: TextLabel.LayoutRun) {
            if codeView.superview != self {
                addSubview(codeView)
            }
            codeView.textView.delegate = self
            codeView.previewAction = codePreviewHandler
            codeView.isExpanded = expandedCodeBlocks.contains(codeView.codeBlockIndex) && codeView.isCollapsible
            // Content and state change on rebuilds that keep this view's
            // frame — a stream growing past the preview height never moves
            // the frame again. Scroll geometry and the bar buttons are only
            // recomputed in the view's own layout, so ask for one on every
            // sync rather than let them go stale.
            codeView.setNeedsLayout()
            codeView.preferredHeightDidChange = { [weak self, weak codeView] in
                guard let self, let codeView, codeView.superview === self else { return }
                let blockIndex = codeView.codeBlockIndex
                let isExpanded = codeView.isExpanded
                DispatchQueue.main.async { [weak self, weak codeView] in
                    guard let self, let codeView, codeView.superview === self else { return }
                    if isExpanded {
                        self.expandedCodeBlocks.insert(blockIndex)
                    } else {
                        self.expandedCodeBlocks.remove(blockIndex)
                    }
                    self.codeBlockExpansionDidChange?(blockIndex, isExpanded)
                }
            }
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
            // A container with no width lays out no runs, and hiding every
            // context view against that empty layout blanks them until a later
            // pass happens to re-place them. Keep whatever a previous pass
            // placed until the container has a size again.
            guard textLabelView.bounds.width > 0 else { return }

            var placed: Set<PlatformView> = []
            var runCount = 0

            for run in textLabelView.layoutRuns(matching: .contextView) {
                runCount += 1
                if let codeView = run.attributes[.contextView] as? CodeView {
                    syncCodeView(codeView, with: run)
                    placed.insert(codeView)
                    continue
                }

                if let tableView = run.attributes[.contextView] as? TableView {
                    syncTableView(tableView, with: run)
                    placed.insert(tableView)
                }
            }

            // A view whose line did not survive this layout pass has no known
            // position, and its previous frame belongs to a layout that no longer
            // exists. Hide it rather than let it paint over the text — but only
            // once this pass actually saw runs. A rebuild caught before the text
            // layout produced any would otherwise hide every block and blank it
            // until a later, unrelated layout pass puts it back.
            if runCount > 0 || contextViews.isEmpty {
                for view in contextViews {
                    view.isHidden = !placed.contains(view)
                }
            }

            syncBlockquoteBars()
        }

        /// Gives every blockquote a bar spanning all of its lines.
        ///
        /// The bar is a view instead of a line drawing action because an action
        /// only runs for the lines a redraw touches, which paints a bar spanning
        /// several lines in fragments.
        private func syncBlockquoteBars() {
            let spans = blockquoteLineSpans()

            while blockquoteBars.count < spans.count {
                let bar = BlockquoteBarView()
                blockquoteBars.append(bar)
                addSubview(bar)
            }
            while blockquoteBars.count > spans.count {
                blockquoteBars.removeLast().removeFromSuperview()
            }

            for (bar, span) in zip(blockquoteBars, spans) {
                bar.setTheme(theme)
                bar.isHidden = false
                setFrameIfNeeded(for: bar, to: span)
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
