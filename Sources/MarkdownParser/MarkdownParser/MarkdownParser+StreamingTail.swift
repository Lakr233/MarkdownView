//
//  MarkdownParser+StreamingTail.swift
//  MarkdownView
//

import Foundation

public extension MarkdownParser {
    /// Parses a document that is still being written.
    ///
    /// With `isStreaming` set, the unfinished end of the document is closed the
    /// way it is most likely to end before it is parsed — see
    /// ``StreamingTail`` — so `**bo` already shows as bold and a half-typed
    /// list marker does not flash as an empty item. Everything before the last
    /// block parses exactly as it would on its own.
    ///
    /// With `isStreaming` off this is ``parse(_:)``, unchanged.
    func parse(_ markdown: String, isStreaming: Bool) -> ParseResult {
        guard isStreaming else { return parse(markdown) }
        return parse(StreamingTail(closing: markdown).applied(to: markdown))
    }

    /// How the unfinished end of a streamed document is closed before parsing.
    ///
    /// The repaired text is the first ``keptLength`` UTF-8 bytes of the
    /// document followed by ``suffix``: the repair only drops the end of the
    /// last line and appends closers, never edits the middle. So every block
    /// before the one being written stays byte for byte what it was, and a
    /// rebuild keeps reusing them.
    ///
    /// What it does, all at the end of the document:
    /// - Holds back a last line of nothing but markers (`-`, `1.`, `#`, `>`,
    ///   `**`, a setext `---` that would turn the line above into a heading).
    /// - Holds back an unfinished fence info line, so a language is not
    ///   guessed from half its name, and a partial closing fence.
    /// - Closes emphasis, strong, strikethrough and code spans opened on the
    ///   last line, innermost first, and drops an opener nothing follows.
    /// - Closes an unfinished link destination and drops an unfinished image.
    /// - Gives a table header row its delimiter row before it arrives.
    /// - Holds back a partial HTML tag, entity or a trailing backslash.
    ///
    /// Inside fenced code and unclosed `$$` math it changes nothing.
    struct StreamingTail: Equatable, Sendable {
        /// How many UTF-8 bytes of the document are kept.
        public let keptLength: Int
        /// What is appended after them.
        public let suffix: String

        public init(keptLength: Int, suffix: String) {
            self.keptLength = keptLength
            self.suffix = suffix
        }

        /// The repair for `markdown`.
        public init(closing markdown: String) {
            var markdown = markdown
            let repair = markdown.withUTF8 { StreamingTailScanner(bytes: $0).repair() }
            self.init(keptLength: repair.keep, suffix: repair.suffix)
        }

        /// The repaired text of `markdown`, the document this was computed for.
        public func applied(to markdown: String) -> String {
            let utf8 = markdown.utf8
            guard keptLength < utf8.count || !suffix.isEmpty else { return markdown }
            let kept = utf8.prefix(keptLength)
            return String(decoding: kept, as: UTF8.self) + suffix
        }
    }
}
