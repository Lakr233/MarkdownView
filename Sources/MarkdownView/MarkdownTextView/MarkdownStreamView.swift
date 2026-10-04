//
//  MarkdownStreamView.swift
//  MarkdownView
//

import Foundation
import Litext
import LitextAnimation
import QuartzCore

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A ``MarkdownTextView`` for a document that is still being written, such as
/// an answer streaming in token by token.
///
/// While ``isStreaming`` is `true`, content passed to ``setContent(_:)`` is
/// rebuilt at a pace set by what a rebuild costs, and the text it adds fades
/// in, in the body and inside code blocks; new code blocks and tables fade in
/// whole. Everything else appears at once: ``setContentImmediately(_:)``, a
/// theme, a finished highlight, and any content while ``isStreaming`` is
/// `false`, when the view behaves exactly like a ``MarkdownTextView``.
///
/// In a reused table or list row, set ``streamIdentity`` to the item the row
/// shows and ``isStreaming`` to whether that item is still being written,
/// then fill the row with ``setContentImmediately(_:)`` the first time and
/// ``setContent(_:)`` after that:
///
/// ```swift
/// row.markdownView.streamIdentity = message.id
/// row.markdownView.isStreaming = message.isGenerating
/// if isFirstFill {
///     row.markdownView.setContentImmediately(content)
/// } else {
///     row.markdownView.setContent(content)
/// }
/// ```
///
/// A row that shows another item never replays its text, and a view that is
/// not in a window, such as one measuring a row's height, never animates.
open class MarkdownStreamView: MarkdownTextView {
    /// The label that draws the document body.
    public var streamLabel: LTXAnimatableLabel {
        textLabelView as! LTXAnimatableLabel
    }

    /// Whether the document is still being written. Only then do rebuilds
    /// animate and follow their own pace.
    ///
    /// Turning it on sets ``MarkdownTextView/throttleInterval`` to `nil`, since
    /// the view paces streamed content itself. Turning it off shows any content
    /// still waiting at once, lets the text in flight finish fading in, and
    /// restores the interval the view had before.
    open var isStreaming = false {
        didSet {
            guard isStreaming != oldValue else { return }
            if isStreaming {
                idleThrottleInterval = throttleInterval
                throttleInterval = nil
            } else {
                applyPendingContent()
                throttleInterval = idleThrottleInterval
            }
        }
    }

    /// What the view shows, for telling a reused row's next item from more of
    /// the same one. Changing it ends the animations in flight.
    open var streamIdentity: AnyHashable? {
        get { streamLabel.animationIdentity }
        set { streamLabel.animationIdentity = newValue }
    }

    /// The effect streamed text appears with. Defaults to an
    /// `LTXFadeInAnimator`; `nil` shows streamed text at once.
    open var animator: (any LTXTextAnimator)? {
        get { streamLabel.animator }
        set { streamLabel.animator = newValue }
    }

    /// The share of the main thread streamed rebuilds may take. Each rebuild
    /// waits until its cost, divided by this share, has passed since the last
    /// one, within ``rebuildIntervals``.
    open var rebuildLoad: Double = 0.15

    /// The shortest and longest wait between two streamed rebuilds.
    open var rebuildIntervals: ClosedRange<TimeInterval> = (1.0 / 30) ... (1.0 / 8)

    /// How long a code block or table that streams in takes to fade in.
    open var contextViewFadeDuration: TimeInterval = 0.25

    /// `throttleInterval` to restore once streaming ends.
    private var idleThrottleInterval: TimeInterval? = 1 / 20
    private var pendingContent: MarkdownContent?
    private var rebuildTimer: Timer?
    private var nextRebuildTime: CFTimeInterval = 0
    /// What the last streamed rebuild took, for tests and tuning.
    private(set) var lastRebuildDuration: CFTimeInterval = 0

    public init(viewProvider: ReusableViewProvider = .init()) {
        super.init(textLabelView: LTXAnimatableLabel(), viewProvider: viewProvider)
        streamLabel.animator = LTXFadeInAnimator()
        streamLabel.animationPolicy = LTXClosureAnimationPolicy { [weak self] context in
            guard let self else { return false }
            // Streamed text fades in. Anything else that only restyles or trims the
            // text keeps the text in flight fading; the rest ends it.
            return (isAnimatingRebuild && LTXDefaultAnimationPolicy().shouldAnimate(context))
                || (!context.change.hasInsertion && context.wasAnimating)
        }
    }

    /// Whether the rebuild in progress shows streamed content while streaming.
    private var isAnimatingRebuild: Bool {
        isStreaming && rebuildIsStreamed
    }

    // MARK: - Content

    override open func setContentImmediately(_ content: MarkdownContent) {
        cancelPendingContent()
        super.setContentImmediately(content)
    }

    override open func reset() {
        cancelPendingContent()
        super.reset()
    }

    override func deliverStreamedContent(_ content: MarkdownContent) {
        guard isStreaming else {
            super.deliverStreamedContent(content)
            return
        }
        pendingContent = content
        guard rebuildTimer == nil else { return }
        let delay = nextRebuildTime - CACurrentMediaTime()
        guard delay > 0 else {
            applyPendingContent()
            return
        }
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildTimer = nil
                self?.applyPendingContent()
            }
        }
        // Common modes, so the answer keeps arriving while the reader scrolls.
        RunLoop.main.add(timer, forMode: .common)
        rebuildTimer = timer
    }

    /// Rebuilds the newest streamed content, and schedules the next rebuild
    /// no sooner than its cost allows.
    private func applyPendingContent() {
        rebuildTimer?.invalidate()
        rebuildTimer = nil
        guard let content = pendingContent else { return }
        pendingContent = nil
        let start = CACurrentMediaTime()
        use(content, streamed: true)
        let end = CACurrentMediaTime()
        lastRebuildDuration = end - start
        nextRebuildTime = end + Self.rebuildInterval(
            forCost: lastRebuildDuration,
            load: rebuildLoad,
            within: rebuildIntervals,
        )
    }

    private func cancelPendingContent() {
        rebuildTimer?.invalidate()
        rebuildTimer = nil
        pendingContent = nil
    }

    /// The wait after a rebuild that cost `cost`, keeping rebuilds to `load`
    /// of the main thread.
    static func rebuildInterval(
        forCost cost: CFTimeInterval,
        load: Double,
        within range: ClosedRange<TimeInterval>,
    ) -> TimeInterval {
        let wait = load > 0 ? cost / load : range.upperBound
        return min(max(wait, range.lowerBound), range.upperBound)
    }

    // MARK: - Showing a rebuild

    override open func applyDocument(_ document: NSAttributedString, newContextViews: [PlatformView], animated: Bool) {
        super.applyDocument(document, newContextViews: newContextViews, animated: animated)
        prepareCodeViewsForStreaming()
        guard isAnimatingRebuild, window != nil, contextViewFadeDuration > 0 else { return }
        for view in newContextViews {
            fadeIn(view)
        }
    }

    /// Gives code blocks an animator of their own while streaming, so code
    /// streamed into a block fades in like the body text.
    ///
    /// A block animates only text appended to what it showed, so a pooled
    /// code view taking another block shows it at once.
    private func prepareCodeViewsForStreaming() {
        for case let codeView as CodeView in contextViews {
            let label = codeView.textView
            guard isStreaming, animator != nil else {
                label.animator = nil
                continue
            }
            guard label.animator == nil else { continue }
            label.animator = LTXFadeInAnimator()
            label.animationPolicy = LTXClosureAnimationPolicy { [weak self] context in
                guard let self else { return false }
                // A finished highlight only recolours the code, so the code in flight
                // keeps fading instead of showing at once.
                return (isAnimatingRebuild
                    && context.change.isAppend
                    && LTXDefaultAnimationPolicy().shouldAnimate(context))
                    || (!context.change.hasInsertion && context.wasAnimating)
            }
        }
    }

    private func fadeIn(_ view: PlatformView) {
        #if canImport(UIKit)
            view.alpha = 0
            UIView.animate(
                withDuration: contextViewFadeDuration,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
            ) {
                view.alpha = 1
            }
        #elseif canImport(AppKit)
            view.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = contextViewFadeDuration
                view.animator().alphaValue = 1
            }
        #endif
    }
}
