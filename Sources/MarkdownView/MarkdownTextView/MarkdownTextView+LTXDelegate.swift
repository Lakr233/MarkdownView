//
//  MarkdownTextView+LTXDelegate.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import Litext

#if canImport(UIKit)
    import UIKit

    extension MarkdownTextView: LTXLabelDelegate {
        public func ltxLabelSelectionDidChange(_: Litext.LTXLabel, selection _: NSRange?) {
            // reserved for future use
        }

        public func ltxLabelDetectedUserEventMovingAtLocation(_ label: Litext.LTXLabel, location: CGPoint) {
            guard let scrollView = trackedScrollView else { return }
            guard scrollView.contentSize.height > scrollView.bounds.height else { return }

            let edgeDetection = CGFloat(16)
            let scrollViewVisibleRect = CGRect(origin: scrollView.contentOffset, size: scrollView.bounds.size)
                .insetBy(dx: -10000, dy: edgeDetection)
            let locationInScrollView = label.convert(location, to: scrollView)
            guard !scrollViewVisibleRect.contains(locationInScrollView) else {
                return
            }

            var currentOffset = scrollView.contentOffset
            if locationInScrollView.y < scrollViewVisibleRect.minY {
                currentOffset.y -= abs(scrollViewVisibleRect.minY - locationInScrollView.y)
            } else {
                currentOffset.y += abs(locationInScrollView.y - scrollViewVisibleRect.maxY)
            }
            currentOffset.y = max(0, currentOffset.y)
            currentOffset.y = min(
                currentOffset.y,
                scrollView.contentSize.height - scrollView.bounds.height
                    + scrollView.contentInset.top + scrollView.contentInset.bottom
            )
            scrollView.setContentOffset(currentOffset, animated: false)
        }

        public func ltxLabelDidTapOnHighlightContent(_: LTXLabel, region: LTXHighlightRegion?, location: CGPoint) {
            guard let highlightRegion = region else {
                return
            }

            if let latexContent = highlightRegion.attributes[.mathLatexContent] as? String {
                presentMathPreview(for: latexContent, theme: theme)
                return
            }

            let link = highlightRegion.attributes[NSAttributedString.Key.link]
            let range = highlightRegion.stringRange
            if let url = link as? URL {
                linkHandler?(.url(url), range, location)
            } else if let string = link as? String {
                linkHandler?(.string(string), range, location)
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    extension MarkdownTextView: LTXLabelDelegate {
        public func ltxLabelSelectionDidChange(_: Litext.LTXLabel, selection _: NSRange?) {
            // reserved for future use
        }

        public func ltxLabelDetectedUserEventMovingAtLocation(_ label: Litext.LTXLabel, location: CGPoint) {
            guard let scrollView = trackedScrollView else { return }
            guard let documentView = scrollView.documentView else { return }
            guard documentView.bounds.height > scrollView.bounds.height else { return }

            let edgeDetection = CGFloat(16)
            let visibleRect = scrollView.documentVisibleRect.insetBy(dx: -10000, dy: edgeDetection)
            let locationInScrollView = label.convert(location, to: documentView)

            guard !visibleRect.contains(locationInScrollView) else {
                return
            }

            var newOrigin = scrollView.documentVisibleRect.origin
            if locationInScrollView.y < visibleRect.minY {
                newOrigin.y -= abs(visibleRect.minY - locationInScrollView.y)
            } else {
                newOrigin.y += abs(locationInScrollView.y - visibleRect.maxY)
            }
            newOrigin.y = max(0, newOrigin.y)
            newOrigin.y = min(newOrigin.y, documentView.bounds.height - scrollView.bounds.height)
            documentView.scroll(newOrigin)
        }

        public func ltxLabelDidTapOnHighlightContent(_: LTXLabel, region: LTXHighlightRegion?, location: CGPoint) {
            guard let highlightRegion = region else {
                return
            }

            if let latexContent = highlightRegion.attributes[.mathLatexContent] as? String {
                presentMathPreview(for: latexContent, theme: theme)
                return
            }

            let link = highlightRegion.attributes[NSAttributedString.Key.link]
            let range = highlightRegion.stringRange
            if let url = link as? URL {
                linkHandler?(.url(url), range, location)
            } else if let string = link as? String {
                linkHandler?(.string(string), range, location)
            }
        }
    }
#endif
