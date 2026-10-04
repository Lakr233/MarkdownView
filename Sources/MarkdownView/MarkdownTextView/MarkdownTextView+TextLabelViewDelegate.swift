//
//  MarkdownTextView+TextLabelViewDelegate.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/9/25.
//

import Litext

/// The delegate methods live in the class body, so a subclass can override
/// them; see `MarkdownTextView`.
extension MarkdownTextView: TextLabelViewDelegate {}

#if canImport(UIKit)
    extension MarkdownTextView {
        func autoScroll(_ scrollView: UIScrollView, toFollowDragAt location: CGPoint, in label: TextLabelView) {
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
            let minOffsetY = -scrollView.adjustedContentInset.top
            let maxOffsetY = max(
                minOffsetY,
                scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height,
            )
            currentOffset.y = min(max(currentOffset.y, minOffsetY), maxOffsetY)
            scrollView.setContentOffset(currentOffset, animated: false)
        }
    }

#elseif canImport(AppKit)
    extension MarkdownTextView {
        func autoScroll(_ scrollView: NSScrollView, toFollowDragAt location: CGPoint, in label: TextLabelView) {
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
            // The clip view knows its own limits — content insets and the
            // room scrollers take — so let it clamp the origin.
            let clipView = scrollView.contentView
            let proposed = CGRect(origin: newOrigin, size: clipView.bounds.size)
            clipView.scroll(to: clipView.constrainBoundsRect(proposed).origin)
            scrollView.reflectScrolledClipView(clipView)
        }
    }
#endif
