import Foundation
@testable import MarkdownView
import Testing

/// Every view on screen shares one highlighter, so a view asking for its code
/// to be highlighted must not cost another view the request it already made.
@MainActor
struct CodeHighlighterSchedulingTests {
    /// Stands in for a view: only its identity names the requester.
    private final class Requester {}

    /// Its own highlighter, so requests other tests make while these run
    /// cannot queue ahead of these and starve them.
    private let highlighter = CodeHighlighter()

    private func request(_ content: String, language: String = "swift") -> CodeHighlightRequest {
        .init(
            key: highlighter.key(for: content, language: language),
            content: content,
            language: language,
        )
    }

    /// Polls until every key is cached, giving up after `attempts` polls.
    ///
    /// Counted in polls, not wall time: a result reaches the cache on the main
    /// actor, and other suites running alongside can hold it for seconds. A
    /// poll only runs when this test has the main actor, so the budget is
    /// spent only on time the highlighter could have used.
    @MainActor
    private func waitUntilCached(_ keys: [Int], attempts: Int = 500) async -> Bool {
        for _ in 0 ..< attempts {
            if keys.allSatisfy({ highlighter.cachedHighlightMap(for: $0) != nil }) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    @Test
    func `A request from one view survives another view scheduling its own`() async {
        let tag = UUID().uuidString
        // The first request goes straight to the worker; the second waits in
        // the queue, which is where a later caller could throw it away.
        let first = request("let first = \"\(tag)\"")
        let queued = request("let queued = \"\(tag)\"")
        let other = request("let other = \"\(tag)\"")

        let viewA = Requester()
        let viewB = Requester()
        highlighter.scheduleHighlight(requests: [first, queued], requester: ObjectIdentifier(viewA))
        highlighter.scheduleHighlight(requests: [other], requester: ObjectIdentifier(viewB))

        let finished = await waitUntilCached([first.key, queued.key, other.key])
        withExtendedLifetime((viewA, viewB)) {}
        #expect(finished, "a queued request from another view was dropped")
    }

    @Test
    func `A view asking again replaces what it asked for before`() async {
        let tag = UUID().uuidString
        let blocker = request("let blocker = \"\(tag)\"")
        let shorter = request("let streamed = \"\(tag)")
        let longer = request("let streamed = \"\(tag)\"\nprint(streamed)")

        let view = Requester()
        highlighter.scheduleHighlight(requests: [blocker, shorter], requester: ObjectIdentifier(view))
        // Rebuilding asks again for every block not yet highlighted.
        highlighter.scheduleHighlight(requests: [blocker, longer], requester: ObjectIdentifier(view))

        let finished = await waitUntilCached([blocker.key, longer.key])
        withExtendedLifetime(view) {}
        #expect(finished)
        // Given time, a superseded prefix would have been highlighted by now.
        try? await Task.sleep(for: .milliseconds(300))
        #expect(highlighter.cachedHighlightMap(for: shorter.key) == nil)
    }
}
