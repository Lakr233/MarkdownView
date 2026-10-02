import Foundation

/// What a highlighted range is. A highlight map records the kind, not a
/// colour, so one map serves every theme; ``MarkdownTheme/Syntax`` picks the
/// colour when the code is drawn.
public enum SyntaxToken: Hashable, CaseIterable, Sendable {
    /// `comment`, `quote`.
    case comment
    /// `keyword`, `literal` and markup tag names.
    case keyword
    /// `string`.
    case string
    /// `number`, and `title`: the name a declaration introduces.
    case number
    /// `type`, `built_in`, `class`.
    case type
    /// `attr`: object keys and markup attributes.
    case attribute
    /// `meta`: preprocessor directives, attributes and decorators.
    case meta
    /// `variable`: shell and template variables.
    case variable
}
