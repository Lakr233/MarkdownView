//
//  MarkLineDrawingAction.swift
//  MarkdownView
//

import CoreText
import Foundation
import Litext

/// Draws a list marker or a thematic break, and compares by what it draws.
///
/// Every rebuild of a document makes new actions, but what one draws depends
/// only on its ``Mark``, the theme it falls back to, and for a break the view
/// it spans: the drawing reads its colour and font from the line it is handed. Equal marks make equal attributes, so a rebuilt list compares
/// equal to the one it replaces, up to the item being written, and the label
/// keeps the lines it typeset before the edit.
final class MarkLineDrawingAction: TextLabel.LineDrawingAction {
    enum Mark: Hashable {
        case bullet(depth: Int)
        case numbered(Int)
        case checkbox(isDone: Bool)
        case thematicBreak
    }

    nonisolated let mark: Mark
    /// The colour and font the drawing falls back to when its line carries none.
    nonisolated let theme: MarkdownTheme
    /// The view the drawing measures from. Actions of two views are not
    /// interchangeable.
    nonisolated let owner: ObjectIdentifier?

    init(
        mark: Mark,
        theme: MarkdownTheme,
        owner: ObjectIdentifier?,
        action: @escaping (CGContext, CTLine, CGPoint) -> Void,
    ) {
        self.mark = mark
        self.theme = theme
        self.owner = owner
        super.init(action: action)
    }

    override nonisolated func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MarkLineDrawingAction else { return false }
        return other === self || (mark == other.mark && owner == other.owner && theme == other.theme)
    }

    override nonisolated var hash: Int {
        mark.hashValue
    }
}
