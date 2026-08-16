//
//  CodeBlockCollapse.swift
//  MarkdownView
//

import Foundation

/// Display options for fenced code blocks that apply to every view in the
/// process. Hosts flip these from user settings and reload their content.
public enum CodeBlockCollapse {
    /// Whether long code blocks may collapse into a scrollable preview. When
    /// disabled, every block reserves its full height and the disclosure
    /// button stays hidden.
    nonisolated(unsafe) public static var isEnabled: Bool = true
}
