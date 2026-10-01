import Foundation
@testable import MarkdownView
import Testing

/// Every view on screen shares one highlighter, so a view asking for its code
/// to be highlighted must not cost another view the request it already made.
struct CodeHighlighterSchedulingTests {
    /// Stands in for a view: only its identity names the requester.
    private final class Requester {}

    @MainActor
    private func request(_ content: String, language: String = "swift") -> CodeHighlightRequest {
        .init(
            key: CodeHighlighter.current.key(for: content, language: language),
            content: content,
            language: language
        )
    }

    @MainActor
    private func waitUntilCached(_ keys: [Int], timeout: Duration = .seconds(10)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if keys.allSatisfy({ CodeHighlighter.current.cachedHighlightMap(for: $0) != nil }) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    @MainActor
    @Test("A request from one view survives another view scheduling its own")
    func requestsFromAnotherViewAreNotDropped() async {
        let tag = UUID().uuidString
        // The first request goes straight to the worker; the second waits in
        // the queue, which is where a later caller could throw it away.
        let first = request("let first = \"\(tag)\"")
        let queued = request("let queued = \"\(tag)\"")
        let other = request("let other = \"\(tag)\"")

        let viewA = Requester()
        let viewB = Requester()
        CodeHighlighter.current.scheduleHighlight(requests: [first, queued], requester: ObjectIdentifier(viewA))
        CodeHighlighter.current.scheduleHighlight(requests: [other], requester: ObjectIdentifier(viewB))

        let finished = await waitUntilCached([first.key, queued.key, other.key])
        withExtendedLifetime((viewA, viewB)) {}
        #expect(finished, "a queued request from another view was dropped")
    }

    @MainActor
    @Test("A view asking again replaces what it asked for before")
    func streamedPrefixIsSuperseded() async {
        let tag = UUID().uuidString
        let blocker = request("let blocker = \"\(tag)\"")
        let shorter = request("let streamed = \"\(tag)")
        let longer = request("let streamed = \"\(tag)\"\nprint(streamed)")

        let view = Requester()
        CodeHighlighter.current.scheduleHighlight(requests: [blocker, shorter], requester: ObjectIdentifier(view))
        // Rebuilding asks again for every block not yet highlighted.
        CodeHighlighter.current.scheduleHighlight(requests: [blocker, longer], requester: ObjectIdentifier(view))

        let finished = await waitUntilCached([blocker.key, longer.key])
        withExtendedLifetime(view) {}
        #expect(finished)
        // Given time, a superseded prefix would have been highlighted by now.
        try? await Task.sleep(for: .milliseconds(300))
        #expect(CodeHighlighter.current.cachedHighlightMap(for: shorter.key) == nil)
    }
}
