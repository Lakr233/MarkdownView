import Foundation

#if canImport(NaturalLanguage)
    import NaturalLanguage
#endif

@MainActor
enum MarkdownContentLocale {
    private final class CachedLanguageRuns: NSObject {
        let runs: [(NSRange, String)]

        init(runs: [(NSRange, String)]) {
            self.runs = runs
        }
    }

    private static let cache = NSCache<NSString, CachedLanguageRuns>()

    static func applyLanguageAttributes(
        to attributedString: NSMutableAttributedString,
        fallbackLocale: Locale
    ) {
        guard attributedString.length > 0 else { return }

        let runs = cachedLanguageRuns(for: attributedString.string, fallbackLocale: fallbackLocale)
        for (range, language) in runs {
            attributedString.addAttribute(
                .coreTextLanguage,
                value: language,
                range: range
            )
        }
    }

    static func dominantLanguageIdentifier(
        for text: String,
        fallbackLocale: Locale
    ) -> String? {
        let scriptLanguage = scriptLanguageIdentifier(for: text, fallbackLocale: fallbackLocale)
        if scriptLanguage != nil {
            return scriptLanguage
        }

        #if canImport(NaturalLanguage)
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            return recognizer.dominantLanguage?.rawValue
        #else
            return nil
        #endif
    }

    private static func languageIdentifier(
        for text: String,
        range: NSRange,
        in fullText: String,
        fallbackLocale: Locale
    ) -> String? {
        if text.unicodeScalars.contains(where: { isHan($0.value) }) {
            if hasKanaNear(range: range, in: fullText) {
                return "ja"
            }
            if hasHangulNear(range: range, in: fullText) {
                return "ko"
            }
        }
        return scriptLanguageIdentifier(for: text, fallbackLocale: fallbackLocale)
    }

    private static func scriptLanguageIdentifier(
        for text: String,
        fallbackLocale: Locale
    ) -> String? {
        var containsHan = false
        var containsArabic = false
        var containsHebrew = false

        for scalar in text.unicodeScalars {
            let value = scalar.value
            if isHiragana(value) || isKatakana(value) {
                return "ja"
            }
            if isHangul(value) {
                return "ko"
            }
            if isHan(value) {
                containsHan = true
            }
            if isArabic(value) {
                containsArabic = true
            }
            if isHebrew(value) {
                containsHebrew = true
            }
        }

        if containsHan {
            return preferredCJKLanguageIdentifier(fallbackLocale)
        }
        if containsArabic {
            return "ar"
        }
        if containsHebrew {
            return "he"
        }
        return nil
    }

    private static func preferredCJKLanguageIdentifier(_ locale: Locale) -> String {
        let identifier = locale.identifier
        if identifier.hasPrefix("ja") {
            return "ja"
        }
        if identifier.hasPrefix("ko") {
            return "ko"
        }
        if identifier.hasPrefix("zh") {
            return identifier
        }
        return "zh-Hans"
    }

    private static func characterRanges(in string: String) -> [NSRange] {
        var ranges = [NSRange]()
        var cursor = string.startIndex
        while cursor < string.endIndex {
            let next = string.index(after: cursor)
            ranges.append(NSRange(cursor ..< next, in: string))
            cursor = next
        }
        return ranges
    }

    private static func cachedLanguageRuns(
        for string: String,
        fallbackLocale: Locale
    ) -> [(NSRange, String)] {
        let key = "\(fallbackLocale.identifier)|\(string)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached.runs
        }

        let nsString = string as NSString
        var runs = [(NSRange, String)]()
        var currentLanguage: String?
        var runStart = 0

        func flush(until location: Int) {
            guard let currentLanguage, location > runStart else { return }
            runs.append((NSRange(location: runStart, length: location - runStart), currentLanguage))
        }

        for range in characterRanges(in: string) {
            let character = nsString.substring(with: range)
            let language = languageIdentifier(
                for: character,
                range: range,
                in: string,
                fallbackLocale: fallbackLocale
            )
            if language != currentLanguage {
                flush(until: range.location)
                currentLanguage = language
                runStart = range.location
            }
        }

        flush(until: nsString.length)
        cache.setObject(CachedLanguageRuns(runs: runs), forKey: key)
        return runs
    }

    private static func hasKanaNear(range: NSRange, in string: String) -> Bool {
        hasNearbyScalar(range: range, in: string) { isHiragana($0) || isKatakana($0) }
    }

    private static func hasHangulNear(range: NSRange, in string: String) -> Bool {
        hasNearbyScalar(range: range, in: string, matching: isHangul)
    }

    private static func hasNearbyScalar(
        range: NSRange,
        in string: String,
        matching predicate: (UInt32) -> Bool
    ) -> Bool {
        let nsString = string as NSString
        let tokenRange = tokenRange(containing: range, in: nsString)
        let lower = tokenRange.location
        let upper = tokenRange.location + tokenRange.length
        guard upper > lower else { return false }
        let nearby = nsString.substring(with: NSRange(location: lower, length: upper - lower))
        return nearby.unicodeScalars.contains { predicate($0.value) }
    }

    private static func tokenRange(containing range: NSRange, in string: NSString) -> NSRange {
        var lower = range.location
        var upper = range.location + range.length

        while lower > 0 {
            let previousRange = NSRange(location: lower - 1, length: 1)
            guard !isTokenBoundary(string.substring(with: previousRange)) else { break }
            lower -= 1
        }

        while upper < string.length {
            let nextRange = NSRange(location: upper, length: 1)
            guard !isTokenBoundary(string.substring(with: nextRange)) else { break }
            upper += 1
        }

        return NSRange(location: lower, length: upper - lower)
    }

    private static func isTokenBoundary(_ string: String) -> Bool {
        string.unicodeScalars.allSatisfy {
            CharacterSet.whitespacesAndNewlines.contains($0)
                || CharacterSet.punctuationCharacters.contains($0)
                || CharacterSet.symbols.contains($0)
        }
    }

    private static func isHan(_ value: UInt32) -> Bool {
        (0x3400 ... 0x4DBF).contains(value)
            || (0x4E00 ... 0x9FFF).contains(value)
            || (0xF900 ... 0xFAFF).contains(value)
            || (0x20000 ... 0x2A6DF).contains(value)
            || (0x2A700 ... 0x2B73F).contains(value)
            || (0x2B740 ... 0x2B81F).contains(value)
            || (0x2B820 ... 0x2CEAF).contains(value)
            || (0x2CEB0 ... 0x2EBEF).contains(value)
            || (0x30000 ... 0x3134F).contains(value)
    }

    private static func isHiragana(_ value: UInt32) -> Bool {
        (0x3040 ... 0x309F).contains(value)
    }

    private static func isKatakana(_ value: UInt32) -> Bool {
        (0x30A0 ... 0x30FF).contains(value)
            || (0x31F0 ... 0x31FF).contains(value)
            || (0xFF66 ... 0xFF9D).contains(value)
    }

    private static func isHangul(_ value: UInt32) -> Bool {
        (0x1100 ... 0x11FF).contains(value)
            || (0x3130 ... 0x318F).contains(value)
            || (0xAC00 ... 0xD7AF).contains(value)
    }

    private static func isArabic(_ value: UInt32) -> Bool {
        (0x0600 ... 0x06FF).contains(value)
            || (0x0750 ... 0x077F).contains(value)
            || (0x08A0 ... 0x08FF).contains(value)
            || (0xFB50 ... 0xFDFF).contains(value)
            || (0xFE70 ... 0xFEFF).contains(value)
    }

    private static func isHebrew(_ value: UInt32) -> Bool {
        (0x0590 ... 0x05FF).contains(value)
    }
}
