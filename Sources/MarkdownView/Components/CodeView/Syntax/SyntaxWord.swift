import Foundation

/// An ASCII identifier packed into two integers, so looking a word up in a
/// keyword table costs a hash of 16 bytes and no allocation.
///
/// Each character takes six bits, ten to an integer, so words up to twenty
/// characters long fit, and zero marks the end. Longer words, and words with
/// characters outside `[A-Za-z0-9_]`, have no packed form and are never
/// keywords.
struct SyntaxWord: Hashable {
    static let maximumLength = 20

    private var low: UInt64 = 0
    private var high: UInt64 = 0

    init?(_ units: UnsafeBufferPointer<UInt16>, from start: Int, to end: Int, foldsCase: Bool) {
        guard end - start <= Self.maximumLength else { return nil }
        for offset in 0 ..< end - start {
            guard let code = Self.code(for: units[start + offset], foldsCase: foldsCase) else { return nil }
            if offset < 10 {
                low |= code << UInt64(offset * 6)
            } else {
                high |= code << UInt64((offset - 10) * 6)
            }
        }
    }

    /// Packs a word from a catalog. Catalog words are written in the case they
    /// match, or in lowercase for a language that folds case.
    init(_ word: Substring) {
        let units = Array(word.utf16)
        let packed = units.withUnsafeBufferPointer { buffer in
            Self(buffer, from: 0, to: buffer.count, foldsCase: false)
        }
        guard let packed else {
            preconditionFailure("catalog word '\(word)' cannot be packed")
        }
        self = packed
    }

    private static func code(for unit: UInt16, foldsCase: Bool) -> UInt64? {
        switch unit {
        case 0x61 ... 0x7A: // a-z
            UInt64(unit - 0x61 + 1)
        case 0x41 ... 0x5A: // A-Z
            foldsCase ? UInt64(unit - 0x41 + 1) : UInt64(unit - 0x41 + 27)
        case 0x30 ... 0x39: // 0-9
            UInt64(unit - 0x30 + 53)
        case 0x5F: // _
            63
        default:
            nil
        }
    }
}

extension Set<SyntaxWord> {
    /// Builds a table from a space-separated list of words.
    init(words: String) {
        self.init(words.split(whereSeparator: \.isWhitespace).map(SyntaxWord.init))
    }
}
