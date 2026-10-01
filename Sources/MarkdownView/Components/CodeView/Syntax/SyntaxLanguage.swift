import Foundation

/// What the scanner needs to know about a language: how its comments and
/// strings are delimited, and which words mean something.
///
/// This is a lexer's view, not a grammar. It colours keywords, literals,
/// strings, comments and numbers well enough to read, and does not try to be
/// right about anything that needs context.
struct SyntaxLanguage {
    enum Mode {
        case code
        /// HTML and XML: tags, attributes and comments; text between tags is left alone.
        case markup
        /// Unified diffs, coloured by each line's first character.
        case diff
    }

    var mode: Mode = .code

    var lineComments: [String] = []
    var blockComment: (open: String, close: String)?

    /// Quotes that open a string ending at the same quote on the same line.
    var quotes: Set<UInt16> = [.doubleQuote, .singleQuote]
    /// Quotes whose strings may span lines.
    var multilineQuotes: Set<UInt16> = []
    /// `"""` and `'''` open strings that end at the same three quotes.
    var tripleQuotes = false
    /// A single quote opens a character literal only (`'a'`, `'\n'`), so a
    /// lone one, a Rust lifetime for instance, is not a string.
    var singleQuoteIsCharacter = false

    var keywords: Set<SyntaxWord> = []
    /// `true`, `nil`, `self`: coloured as keywords, as Xcode does.
    var literals: Set<SyntaxWord> = []
    var types: Set<SyntaxWord> = []
    /// Keywords whose next identifier is the name being declared.
    var declarations: Set<SyntaxWord> = []
    /// Keywords match whatever their case, as in SQL.
    var foldsCase = false

    /// Identifiers starting with a capital letter are types.
    var capitalizedTypes = true
    /// `#include`, `#if`: `#` and the word after it, at the start of a line.
    var directives = false
    /// `@available`, `@dataclass`, `@media`.
    var annotations = false
    /// `$name`, `${name}`, `$1`.
    var variables = false
    /// A word or string followed by this character is a key.
    var keySeparator: UInt16?
    /// Words may contain hyphens: `font-size`, `app-name`.
    var hyphenatedWords = false
}

extension UInt16 {
    static let newline: UInt16 = 0x0A
    static let carriageReturn: UInt16 = 0x0D
    static let space: UInt16 = 0x20
    static let tab: UInt16 = 0x09
    static let doubleQuote: UInt16 = 0x22
    static let singleQuote: UInt16 = 0x27
    static let backtick: UInt16 = 0x60
    static let backslash: UInt16 = 0x5C
    static let hash: UInt16 = 0x23
    static let at: UInt16 = 0x40
    static let dollar: UInt16 = 0x24
    static let colon: UInt16 = 0x3A
    static let equals: UInt16 = 0x3D
    static let openParen: UInt16 = 0x28
    static let openBrace: UInt16 = 0x7B
    static let closeBrace: UInt16 = 0x7D
    static let lessThan: UInt16 = 0x3C
    static let greaterThan: UInt16 = 0x3E
    static let slash: UInt16 = 0x2F
    static let hyphen: UInt16 = 0x2D
    static let period: UInt16 = 0x2E
    static let ampersand: UInt16 = 0x26
    static let semicolon: UInt16 = 0x3B
    static let plus: UInt16 = 0x2B
    static let exclamation: UInt16 = 0x21
    static let question: UInt16 = 0x3F

    var isDigit: Bool {
        self >= 0x30 && self <= 0x39
    }

    var isUppercase: Bool {
        self >= 0x41 && self <= 0x5A
    }

    var isLetter: Bool {
        (self | 0x20) >= 0x61 && (self | 0x20) <= 0x7A
    }

    var isSpace: Bool {
        self == .space || self == .tab
    }

    var isLineBreak: Bool {
        self == .newline || self == .carriageReturn
    }

    /// Letters, `_`, and anything beyond ASCII, so a CJK name is one word.
    var startsIdentifier: Bool {
        isLetter || self == 0x5F || self >= 0x80
    }

    var continuesIdentifier: Bool {
        startsIdentifier || isDigit
    }
}

extension SyntaxLanguage {
    /// The language a fence's info string names, or nil when it names plain
    /// text, which is left uncoloured. A fence that names no language, or one
    /// the catalog does not know, still gets the rules most languages share.
    static func named(_ info: String?) -> SyntaxLanguage? {
        let name = (info ?? "")
            .split(whereSeparator: { $0.isWhitespace || $0 == "{" || $0 == "," })
            .first
            .map { $0.lowercased() } ?? ""
        if let language = catalog[name] {
            return language
        }
        if plainTextNames.contains(name) {
            return nil
        }
        return .generic
    }

    private static let plainTextNames: Set<String> = [
        "text", "txt", "plain", "plaintext", "output", "log", "markdown", "md", "mermaid", "latex", "tex",
    ]
}
