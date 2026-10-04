import Foundation
import MarkdownParser
@testable import MarkdownView
import SwiftUI
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Closing a streamed document's unfinished end must only ever touch the end.
///
/// Everything before the block being written has to stay byte for byte what
/// it was, or the rebuild after every token stops reusing those blocks, and
/// a stream that ends has to land on exactly the document a plain parse gives.
@MainActor
struct MarkdownStreamingTailTests {
    private static func fixture(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "md"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func prefixes(of document: String, step: Int) -> [String] {
        let characters = Array(document)
        var result = stride(from: step, to: characters.count, by: step).map { String(characters[0 ..< $0]) }
        result.append(document)
        return result
    }

    private static func content(_ markdown: String, isStreaming: Bool) -> MarkdownContent {
        MarkdownContent(
            parserResult: MarkdownParser().parse(markdown, isStreaming: isStreaming),
            theme: .default,
            locale: .init(identifier: "en_US"),
        )
    }

    // MARK: - Every prefix of a real document

    @Test(arguments: ["ExampleDocument", "MultilingualStress"])
    func `Every prefix is only cut and extended at its end`(fixture: String) throws {
        let document = try Self.fixture(fixture)
        let parser = MarkdownParser()
        var repairedCount = 0
        for prefix in Self.prefixes(of: document, step: 1) {
            let tail = MarkdownParser.StreamingTail(closing: prefix)
            let repaired = tail.applied(to: prefix)
            #expect(tail.keptLength <= prefix.utf8.count)
            #expect(
                repaired.utf8.starts(with: prefix.utf8.prefix(tail.keptLength)),
                "\(prefix.debugDescription) became \(repaired.debugDescription)",
            )
            guard repaired != prefix else { continue }
            repairedCount += 1
            // Every block but the last parses as it does without the repair.
            let plain = parser.parse(prefix).document
            let streamed = parser.parse(repaired).document
            let settled = min(plain.count, streamed.count) - 1
            if settled > 0 {
                #expect(
                    Array(plain.prefix(settled)) == Array(streamed.prefix(settled)),
                    "after \(prefix.count) characters: \(prefix.suffix(40).debugDescription)",
                )
            }
        }
        #expect(repairedCount > 0)
        #expect(parser.parse(document, isStreaming: true).document == parser.parse(document).document)
    }

    // MARK: - Rebuilds

    /// How many of `content`'s blocks the view's next build takes from its
    /// cache, or `nil` when it cannot use the cache at all.
    private static func cacheHits(in view: MarkdownTextView, for content: MarkdownContent) -> Int? {
        guard view.blockFragmentCache.isUsable(with: view.theme, for: content) else { return nil }
        return content.blocks.indices.count { index in
            view.blockFragmentCache.hit(at: index, matching: content.blocks[index]) != nil
        }
    }

    @Test
    func `Streaming with the repair keeps reusing every settled block`() throws {
        let document = try Self.fixture("ExampleDocument")
        var totals: [Bool: Int] = [:]
        for isStreaming in [false, true] {
            let view = MarkdownTextView()
            view.frame = .init(x: 0, y: 0, width: 480, height: 10)
            var total = 0
            for prefix in Self.prefixes(of: document, step: 7) {
                let content = Self.content(prefix, isStreaming: isStreaming)
                if let hits = Self.cacheHits(in: view, for: content) {
                    total += hits
                    if isStreaming {
                        // The block being written, and the one it may have
                        // just ended, are the only ones built again.
                        #expect(hits >= content.blocks.count - 2, "after \(prefix.count) characters")
                    }
                }
                view.setContentImmediately(content)
                RenderProbe.layout(view)
            }
            totals[isStreaming] = total
        }
        let plain = try #require(totals[false])
        let streamed = try #require(totals[true])
        #expect(streamed >= plain * 95 / 100, "\(streamed) hits streaming, \(plain) plain")
    }

    /// With the repair, a stream mostly only appends: `**bo` shows as bold
    /// `bo` and grows to bold `bold`, where it used to show `**bo` and then
    /// lose the asterisks once they closed.
    @Test
    func `The repaired stream mostly only appends text`() {
        let document = "Hello **bold** and *it* with `code`, and ~~gone~~ at the end."
        var appends: [Bool: Int] = [:]
        for isStreaming in [false, true] {
            let view = MarkdownTextView()
            var previous = ""
            var count = 0
            for prefix in Self.prefixes(of: document, step: 1) {
                view.setContentImmediately(Self.content(prefix, isStreaming: isStreaming))
                // Without the paragraph's newline and the code pill's
                // attachment marks, which close every update.
                let shown = view.textLabelView.attributedText.string
                    .replacingOccurrences(of: "\u{FFFC}", with: "")
                    .trimmingCharacters(in: .newlines)
                if shown.hasPrefix(previous) {
                    count += 1
                }
                previous = shown
            }
            appends[isStreaming] = count
        }
        let total = Self.prefixes(of: document, step: 1).count
        #expect(appends[true] == total, "\(appends[true] ?? 0) of \(total) updates append")
        #expect((appends[false] ?? 0) < total)
    }

    // MARK: - SwiftUI

    @Test
    func `Ending a stream without new text parses again without the repair`() async throws {
        let view = MarkdownTextView()
        let coordinator = MarkdownViewCoordinator()
        coordinator.setTextThrottled("Hello **bold", theme: .default, isStreaming: true, on: view)
        #expect(view.content.blocks == [
            .paragraph(content: [.text("Hello "), .strong(children: [.text("bold")])]),
        ])

        coordinator.setTextThrottled("Hello **bold", theme: .default, isStreaming: false, on: view)
        let plain: [MarkdownBlockNode] = [.paragraph(content: [.text("Hello **bold")])]
        // The throttle delivers it on a later turn of the main actor.
        for _ in 0 ..< 100 where view.content.blocks != plain {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(view.content.blocks == plain)
    }

    @Test
    func `Ending a stream the repair left alone keeps the content on screen`() async throws {
        let view = MarkdownTextView()
        let coordinator = MarkdownViewCoordinator()
        coordinator.setTextThrottled("Hello **bold**.", theme: .default, isStreaming: true, on: view)
        let shown = view.content

        coordinator.setTextThrottled("Hello **bold**.", theme: .default, isStreaming: false, on: view)
        for _ in 0 ..< 100 where coordinator.lastIsStreaming {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(!coordinator.lastIsStreaming)
        #expect(view.content === shown)
        #expect(!coordinator.targetIsStreaming)
    }
}
