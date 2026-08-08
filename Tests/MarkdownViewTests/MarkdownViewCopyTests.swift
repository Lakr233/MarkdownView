import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Blocks that are drawn rather than typeset stand in the text as a single
/// object replacement character. Copying one has to yield the markdown it
/// represents — an unattached replacement character reaches the pasteboard
/// verbatim and pastes as an `[obj]` box.
struct MarkdownViewCopyTests {
    private static let document = """
    A paragraph.

    - First bullet
    - Second bullet
      - Nested bullet

    1. First numbered
    2. Second numbered

    - [ ] Open task
    - [x] Done task

    > A quoted line.

    ---

    ```swift
    let answer = 42
    ```

    | A | B |
    | - | - |
    | 1 | 2 |

    Trailing paragraph.
    """

    @MainActor
    @Test("Copying a whole document yields no invisible placeholder characters")
    func copiedDocumentCarriesNoPlaceholders() throws {
        let copied = try #require(copyAll(Self.document, width: 480))

        #expect(!copied.contains(TextLabel.Attachment.replacementText))
        for scalar in copied.unicodeScalars {
            #expect(
                !scalar.properties.isDefaultIgnorableCodePoint,
                "copied text carries an invisible scalar U+\(String(scalar.value, radix: 16, uppercase: true))"
            )
        }
    }

    @MainActor
    @Test("List markers copy as the markdown they stand for")
    func listMarkersCopyAsMarkdown() throws {
        let copied = try #require(copyAll(Self.document, width: 480))

        #expect(copied.contains("- First bullet"))
        #expect(copied.contains("  - Nested bullet"))
        #expect(copied.contains("1. First numbered"))
        #expect(copied.contains("2. Second numbered"))
        #expect(copied.contains("- [ ] Open task"))
        #expect(copied.contains("- [x] Done task"))
    }

    @MainActor
    @Test("A code block copies its source rather than its placeholder")
    func codeBlockCopiesItsSource() throws {
        let copied = try #require(copyAll("```swift\nlet answer = 42\n```", width: 480))

        #expect(copied.contains("let answer = 42"))
        #expect(!copied.contains(TextLabel.Attachment.replacementText))
    }
}

@MainActor
private func copyAll(_ markdown: String, width: CGFloat) -> String? {
    let view = MarkdownTextView()
    view.setContentImmediately(.init(
        parserResult: MarkdownParser().parse(markdown),
        theme: .default
    ))
    view.frame = .init(x: 0, y: 0, width: width, height: view.boundingSize(for: width).height)
    #if canImport(UIKit)
        view.setNeedsLayout()
        view.layoutIfNeeded()
    #elseif canImport(AppKit)
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    #endif

    // `selectedPlainText()` runs the same attachment substitution as copying
    // without writing to the pasteboard.
    view.textLabelView.selectAll()
    return view.textLabelView.selectedPlainText()
}
