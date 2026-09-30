import Foundation
@testable import MarkdownView
import Testing

/// Every view on screen shares one highlighter, so a view asking for its code
/// to be highlighted must not cost another view the request it already made.
struct CodeHighlighterSchedulingTests {
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

        CodeHighlighter.current.scheduleHighlight(requests: [first, queued])
        CodeHighlighter.current.scheduleHighlight(requests: [other])

        let finished = await waitUntilCached([first.key, queued.key, other.key])
        #expect(finished, "a queued request from another view was dropped")
    }

    @MainActor
    @Test("A streamed block supersedes its own earlier, shorter request")
    func streamedPrefixIsSuperseded() async {
        let tag = UUID().uuidString
        let blocker = request("let blocker = \"\(tag)\"")
        let shorter = request("let streamed = \"\(tag)")
        let longer = request("let streamed = \"\(tag)\"\nprint(streamed)")

        CodeHighlighter.current.scheduleHighlight(requests: [blocker, shorter])
        CodeHighlighter.current.scheduleHighlight(requests: [longer])

        let finished = await waitUntilCached([blocker.key, longer.key])
        #expect(finished)
        // Given time, a superseded prefix would have been highlighted by now.
        try? await Task.sleep(for: .milliseconds(300))
        #expect(CodeHighlighter.current.cachedHighlightMap(for: shorter.key) == nil)
    }
}
