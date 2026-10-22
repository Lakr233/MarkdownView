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
/// in, in the body, inside code blocks and in table cells; new code blocks
/// and tables fade in whole. Everything else appears at once:
/// ``setContentImmediately(_:)``, a theme, a finished highlight, and any
/// content while ``isStreaming`` is `false`, when the view behaves exactly
/// like a ``MarkdownTextView``.
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
                prepareBlocksForStreaming()
            } else {
                applyPendingContent()
                throttleInterval = idleThrottleInterval
            }
        }
    }

    /// What the view shows, for telling a reused row's next item from more of
    /// the same one. Changing it ends the animations in flight, inside code
    /// blocks and tables too.
    open var streamIdentity: AnyHashable? {
        get { streamLabel.animationIdentity }
        set {
            guard newValue != streamLabel.animationIdentity else { return }
            streamLabel.animationIdentity = newValue
            for label in blockLabels {
                label.finishAnimations()
            }
        }
    }

    /// The effect streamed text appears with. Defaults to an
    /// `LTXFadeInAnimator`; `nil` shows streamed text at once, in the body
    /// and in code blocks and tables alike. Each code block and table cell
    /// fades in with an animator of its own, from ``makeBlockAnimator()``.
    open var animator: (any LTXTextAnimator)? {
        get { streamLabel.animator }
        set {
            guard newValue !== streamLabel.animator else { return }
            streamLabel.animator = newValue
            // Blocks follow the new effect from their next change on.
            for label in blockLabels {
                label.animator = nil
                prepareForStreaming(label)
            }
        }
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
    /// The ``streamIdentity`` the last rebuild showed. A streamed rebuild
    /// for another item fills code blocks and tables at once.
    private var shownIdentity: AnyHashable?
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

    /// Whether the rebuild in progress fades in the text it streams into
    /// code blocks and tables: it is animated, and shows more of the item the
    /// last rebuild showed. The body's label tells items apart itself.
    private var animatesBlockText: Bool {
        isAnimatingRebuild && streamIdentity == shownIdentity
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
        shownIdentity = streamIdentity
        prepareBlocksForStreaming()
        guard isAnimatingRebuild, window != nil, contextViewFadeDuration > 0 else { return }
        for view in newContextViews {
            fadeIn(view)
        }
    }

    // MARK: - Text inside blocks

    /// Makes the animator that text streamed into one code block or table
    /// cell fades in with. Called for each such label without one while
    /// ``isStreaming`` is on and ``animator`` is set.
    ///
    /// The default fades the text in the way the body does: an
    /// `LTXFadeInAnimator` with the configuration and speed of ``animator``
    /// when that is one, and with the default configuration otherwise.
    /// Override it to give blocks an effect of their own, or return `nil` to
    /// show their text at once. Return a new animator from every call: an
    /// animator keeps the timeline of one label.
    open func makeBlockAnimator() -> (any LTXTextAnimator)? {
        guard let body = animator as? LTXFadeInAnimator else { return LTXFadeInAnimator() }
        let blockAnimator = LTXFadeInAnimator(configuration: body.configuration)
        blockAnimator.speed = body.speed
        return blockAnimator
    }

    /// The labels inside the code blocks and tables the document shows.
    private var blockLabels: [LTXAnimatableLabel] {
        contextViews.flatMap { view -> [LTXAnimatableLabel] in
            if let codeView = view as? CodeView {
                return [codeView.textView]
            }
            if let tableView = view as? TableView {
                return tableView.cellViews.compactMap { $0 as? LTXAnimatableLabel }
            }
            return []
        }
    }

    /// The policy of every label inside a code block or a table.
    ///
    /// A label animates only text appended to what it showed, so a pooled
    /// view taking another block shows it at once. A finished highlight only
    /// recolours the code, so the code in flight keeps fading instead of
    /// showing at once.
    private lazy var blockAnimationPolicy = LTXClosureAnimationPolicy { [weak self] context in
        guard let self else { return false }
        return (animatesBlockText
            && context.change.isAppend
            && LTXDefaultAnimationPolicy().shouldAnimate(context))
            || (!context.change.hasInsertion && context.wasAnimating)
    }

    /// Gives every label inside a code block or a table an animator of its
    /// own while streaming, so text streamed into a block fades in like the
    /// body's, and has each table do the same for the cells of a new row
    /// before their first text.
    private func prepareBlocksForStreaming() {
        for case let tableView as TableView in contextViews {
            tableView.prepareCell = { [weak self] cell in
                self?.prepareForStreaming(cell)
            }
        }
        for label in blockLabels {
            prepareForStreaming(label)
        }
    }

    /// Gives `label` an animator while the document streams, and takes it
    /// away at the first rebuild after the stream has ended. Until then,
    /// text in flight finishes fading in.
    private func prepareForStreaming(_ label: LTXAnimatableLabel) {
        guard isStreaming, animator != nil else {
            label.animator = nil
            return
        }
        guard label.animator == nil else { return }
        label.animator = makeBlockAnimator()
        label.animationPolicy = blockAnimationPolicy
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
