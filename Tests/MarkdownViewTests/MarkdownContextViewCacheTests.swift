import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Counts the layouts a label builds, which is a whole-document typeset each.
private final class CountingTextLabelView: MarkdownTextLabelView {
    var layoutsBuilt = 0

    override func makeTextLayout(_ attributedText: NSAttributedString) -> TextLabel.Layout {
        layoutsBuilt += 1
        return super.makeTextLayout(attributedText)
    }
}

/// Code blocks and tables are kept in the fragment cache with their views,
/// and a finished highlight colours its code view without rebuilding the
/// document. Both only pay off if nothing the reader sees, copies or selects
/// changes, so every test here checks the rendered result as well as the
/// work that was skipped.
struct MarkdownContextViewCacheTests {
    private static let document = """
    Intro paragraph.

    ```swift
    let first = 1
    ```

    | Name | Value |
    | :-- | --: |
    | alpha | 1 |
    | beta | 2 |

    ```python
    print("second")
    ```

    Closing paragraph.
    """

    @MainActor
    private func countingView(_ markdown: String, width: CGFloat = 480) -> (MarkdownTextView, CountingTextLabelView) {
        let label = CountingTextLabelView()
        let view = MarkdownTextView(textLabelView: label)
        // Twice, so the pooled views have been laid out once and the heights
        // they reserve have settled.
        RenderProbe.show(markdown, in: view, width: width)
        RenderProbe.show(markdown, in: view, width: width)
        return (view, label)
    }

    @MainActor
    private func codeViews(in view: MarkdownTextView) -> [CodeView] {
        view.contextViews.compactMap { $0 as? CodeView }
    }

    @MainActor
    private func tableViews(in view: MarkdownTextView) -> [TableView] {
        view.contextViews.compactMap { $0 as? TableView }
    }

    /// The code each block holds, trimmed the way the code view shows it.
    private func codeSources(_ markdown: String) -> [String] {
        MarkdownParser().parse(markdown).document.compactMap { block in
            guard case let .codeBlock(_, content) = block else { return nil }
            return content.deletingSuffix(of: .whitespacesAndNewlines)
        }
    }

    @MainActor
    private func copiedText(_ view: MarkdownTextView) -> String? {
        view.textLabelView.selectAll()
        defer { view.textLabelView.clearSelection() }
        return view.textLabelView.selectedPlainText()
    }

    /// Code views in the order their attachments appear in the document.
    @MainActor
    private func placedCodeViews(in text: NSAttributedString) -> [CodeView] {
        var result: [CodeView] = []
        text.enumerateAttribute(
            .contextView,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, _, _ in
            if let codeView = value as? CodeView { result.append(codeView) }
        }
        return result
    }

    @MainActor
    private func distinctColors(in codeView: CodeView) -> Set<String> {
        let text = codeView.textView.attributedText
        var colors: Set<String> = []
        text.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, _, _ in
            guard let color = value as? PlatformColor else { return }
            colors.insert(String(describing: color))
        }
        return colors
    }

    /// The paragraph height reserved in the document for `contextView`.
    @MainActor
    private func reservedHeight(for contextView: PlatformView, in text: NSAttributedString) -> CGFloat? {
        var height: CGFloat?
        text.enumerateAttribute(
            .contextView,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, range, stop in
            guard let placed = value as? PlatformView, placed === contextView else { return }
            let style = text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
            height = style?.minimumLineHeight
            stop.pointee = true
        }
        return height
    }

    // MARK: - Work skipped

    @MainActor
    @Test("Rebuilding an unchanged document with code and tables does not typeset it again")
    func unchangedRebuildKeepsTheLayout() throws {
        let (view, label) = countingView(Self.document)
        let digest = RenderProbe.digest(view.textLabelView.attributedText)
        let copied = try #require(copiedText(view))
        let views = view.contextViews.map(ObjectIdentifier.init)
        let layouts = label.layoutsBuilt

        for _ in 0 ..< 3 {
            RenderProbe.show(Self.document, in: view)
        }

        #expect(label.layoutsBuilt == layouts)
        let after = RenderProbe.digest(view.textLabelView.attributedText)
        #expect(after == digest, "\(RenderProbe.firstDifference(digest, after))")
        #expect(copiedText(view) == copied)
        #expect(view.contextViews.map(ObjectIdentifier.init) == views)
        #expect(codeViews(in: view).map(\.content) == codeSources(Self.document))
    }

    @MainActor
    @Test("A finished highlight colours its code view without touching the document")
    func highlightCompletionLeavesTheDocumentAlone() throws {
        // Unique source, so nothing has highlighted it yet.
        let source = "let onlyInHighlightCompletionTest = \"\(UUID().uuidString)\""
        let markdown = "Before.\n\n```swift\n\(source)\n```\n\nAfter."
        let (view, label) = countingView(markdown)
        let codeView = try #require(codeViews(in: view).first)
        #expect(distinctColors(in: codeView).count == 1)

        let document = view.textLabelView.attributedText
        let layouts = label.layoutsBuilt

        let blocks = MarkdownParser().parse(markdown).document
        guard case let .codeBlock(language, content) = try #require(blocks.first(where: {
            if case .codeBlock = $0 { true } else { false }
        })) else { return }
        let key = CodeHighlighter.current.key(for: content, language: language)
        _ = CodeHighlighter.current.highlight(key: key, content: content, language: language)
        NotificationCenter.default.post(
            name: CodeHighlighter.highlightDidUpdateNotification,
            object: nil,
            userInfo: [CodeHighlighter.highlightedKeysUserInfoKey: Set([key])]
        )
        RenderProbe.layout(view)

        #expect(view.textLabelView.attributedText === document)
        #expect(label.layoutsBuilt == layouts)
        #expect(codeViews(in: view).first === codeView)
        #expect(distinctColors(in: codeView).count > 1)
        #expect(codeView.textView.attributedText.string == source)
        #expect(codeView.highlightedKey == key)
    }

    @MainActor
    @Test("A cached code block whose highlight arrived in between is coloured on the next build")
    func reusedCodeBlockPicksUpAnArrivedHighlight() throws {
        let source = "let pickedUpOnReuse = \"\(UUID().uuidString)\""
        let markdown = "```swift\n\(source)\n```"
        let (view, _) = countingView(markdown)
        let codeView = try #require(codeViews(in: view).first)
        #expect(distinctColors(in: codeView).count == 1)

        // Warm the cache without telling anyone, so only the next build can
        // notice.
        let key = try #require(codeView.highlightKey)
        _ = CodeHighlighter.current.highlight(key: key, content: source + "\n", language: "swift")
        RenderProbe.show(markdown, in: view)

        #expect(codeViews(in: view).first === codeView)
        #expect(distinctColors(in: codeView).count > 1)
        #expect(codeView.textView.attributedText.string == source)
    }

    // MARK: - Inputs that change size or appearance still rebuild

    @MainActor
    @Test("Changing a code block's content typesets again and shows the new code")
    func codeContentChangeRelayouts() throws {
        let (view, label) = countingView(Self.document)
        let layouts = label.layoutsBuilt

        let changed = Self.document.replacingOccurrences(of: "let first = 1", with: "let first = 1\nlet more = 2")
        RenderProbe.show(changed, in: view)

        #expect(label.layoutsBuilt > layouts)
        #expect(codeViews(in: view).map(\.content) == codeSources(changed))
        #expect(RenderProbe.attachmentTexts(in: view.textLabelView.attributedText).contains("let first = 1\nlet more = 2\n"))
        let first = try #require(codeViews(in: view).first)
        #expect(reservedHeight(for: first, in: view.textLabelView.attributedText) == first.intrinsicContentSize.height)
    }

    @MainActor
    @Test("Changing a code block's language typesets again and shows the new language")
    func codeLanguageChangeRelayouts() throws {
        let (view, label) = countingView(Self.document)
        let layouts = label.layoutsBuilt

        let changed = Self.document.replacingOccurrences(of: "```swift", with: "```kotlin")
        RenderProbe.show(changed, in: view)

        #expect(label.layoutsBuilt > layouts)
        let first = try #require(codeViews(in: view).first)
        #expect(first.language == "kotlin")
        #expect(first.content == "let first = 1")
        let attachment = try #require(
            view.textLabelView.attributedText.attribute(
                .litextAttachment,
                at: (view.textLabelView.attributedText.string as NSString)
                    .range(of: TextLabel.Attachment.replacementText).location,
                effectiveRange: nil
            ) as? ContextViewAttachment
        )
        #expect(attachment.appearance == .of(first))
    }

    @MainActor
    @Test("Changing the code font typesets again and reserves the new height")
    func codeFontChangeRelayouts() throws {
        let (view, label) = countingView(Self.document)
        let layouts = label.layoutsBuilt
        let first = try #require(codeViews(in: view).first)
        let heightBefore = first.intrinsicContentSize.height

        var theme = view.theme
        theme.fonts.code = .monospacedSystemFont(ofSize: 30, weight: .regular)
        view.theme = theme
        RenderProbe.layout(view)

        #expect(label.layoutsBuilt > layouts)
        let rebuilt = try #require(codeViews(in: view).first)
        #expect(rebuilt.intrinsicContentSize.height > heightBefore)
        #expect(reservedHeight(for: rebuilt, in: view.textLabelView.attributedText) == rebuilt.intrinsicContentSize.height)
        let font = rebuilt.textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont
        #expect(font?.pointSize == 30)
        #expect(rebuilt.content == "let first = 1")
    }

    @MainActor
    @Test("Changing the width reflows the cached code blocks and tables")
    func widthChangeReflows() throws {
        let (view, _) = countingView(Self.document, width: 480)
        let narrowHeight = view.boundingSize(for: 240).height
        RenderProbe.show(Self.document, in: view, width: 240)

        for codeView in codeViews(in: view) {
            #expect(abs(codeView.frame.width - 240) < 1)
            #expect(reservedHeight(for: codeView, in: view.textLabelView.attributedText) == codeView.intrinsicContentSize.height)
        }
        for tableView in tableViews(in: view) {
            #expect(abs(tableView.frame.width - 240) < 1)
            #expect(reservedHeight(for: tableView, in: view.textLabelView.attributedText) == tableView.intrinsicContentHeight)
        }
        #expect(view.frame.height == narrowHeight)

        let fresh = RenderProbe.view(Self.document, width: 240)
        RenderProbe.show(Self.document, in: fresh, width: 240)
        #expect(view.boundingSize(for: 240).height == fresh.boundingSize(for: 240).height)
        #expect(codeViews(in: view).map(\.frame) == codeViews(in: fresh).map(\.frame))
        #expect(tableViews(in: view).map(\.frame) == tableViews(in: fresh).map(\.frame))
    }

    @MainActor
    @Test("Changing a table cell typesets again and shows the new cell")
    func tableCellChangeRelayouts() throws {
        let (view, label) = countingView(Self.document)
        let layouts = label.layoutsBuilt

        let changed = Self.document.replacingOccurrences(of: "| beta | 2 |", with: "| beta | 2 |\n| gamma | 3 |")
        RenderProbe.show(changed, in: view)

        #expect(label.layoutsBuilt > layouts)
        let table = try #require(tableViews(in: view).first)
        #expect(table.contents.map { $0.map(\.string) } == [["Name", "Value"], ["alpha", "1"], ["beta", "2"], ["gamma", "3"]])
        #expect(RenderProbe.attachmentTexts(in: view.textLabelView.attributedText)
            .contains("Name\tValue\nalpha\t1\nbeta\t2\ngamma\t3\n"))
        #expect(reservedHeight(for: table, in: view.textLabelView.attributedText) == table.intrinsicContentHeight)
    }

    @MainActor
    @Test("Changing a table's alignment typesets again and aligns the cells")
    func tableAlignmentChangeRelayouts() throws {
        let (view, label) = countingView(Self.document)
        let layouts = label.layoutsBuilt

        let changed = Self.document.replacingOccurrences(of: "| :-- | --: |", with: "| :-: | :-- |")
        RenderProbe.show(changed, in: view)

        #expect(label.layoutsBuilt > layouts)
        let table = try #require(tableViews(in: view).first)
        #expect(table.columnAlignments == [.center, .left])
        #expect(table.contents.map { $0.map(\.string) } == [["Name", "Value"], ["alpha", "1"], ["beta", "2"]])
    }

    @MainActor
    @Test("Changing the table theme typesets again")
    func tableThemeChangeRelayouts() throws {
        let (view, label) = countingView(Self.document)
        let layouts = label.layoutsBuilt
        let table = try #require(tableViews(in: view).first)
        let heightBefore = table.intrinsicContentHeight

        var theme = view.theme
        theme.fonts.body = .systemFont(ofSize: 34)
        view.theme = theme
        RenderProbe.layout(view)

        #expect(label.layoutsBuilt > layouts)
        let rebuilt = try #require(tableViews(in: view).first)
        #expect(rebuilt.theme == theme)
        #expect(rebuilt.intrinsicContentHeight > heightBefore)
        #expect(reservedHeight(for: rebuilt, in: view.textLabelView.attributedText) == rebuilt.intrinsicContentHeight)
    }

    // MARK: - Identity

    @MainActor
    @Test("Two identical code blocks and tables never share a view")
    func identicalBlocksKeepTheirOwnViews() {
        let block = "```swift\nlet same = 1\n```"
        let table = "| A | B |\n| - | - |\n| 1 | 2 |"
        let markdown = [block, table, block, table].joined(separator: "\n\n")
        let (view, _) = countingView(markdown)

        func check(_ markdown: String) {
            let codes = codeViews(in: view)
            let tables = tableViews(in: view)
            #expect(Set(codes.map(ObjectIdentifier.init)).count == codes.count)
            #expect(Set(tables.map(ObjectIdentifier.init)).count == tables.count)
            #expect(codes.map(\.content) == codeSources(markdown))
            #expect(placedCodeViews(in: view.textLabelView.attributedText).map(ObjectIdentifier.init)
                == codes.map(ObjectIdentifier.init))
            let visible = view.subviews.compactMap { $0 as? CodeView }.filter { !$0.isHidden }
            #expect(visible.count == codes.count)
            let frames = codes.map(\.frame)
            #expect(Set(frames.map(\.minY)).count == frames.count)
        }

        check(markdown)
        for _ in 0 ..< 3 {
            RenderProbe.show(markdown, in: view)
            check(markdown)
        }
        // Shift every position by putting a third copy in front.
        let shifted = block + "\n\n" + markdown
        RenderProbe.show(shifted, in: view)
        check(shifted)
        RenderProbe.show(markdown, in: view)
        check(markdown)
    }

    @MainActor
    @Test("A cached view changed behind the builder's back is rebuilt, not trusted")
    func driftedViewIsRebuilt() throws {
        let (view, _) = countingView(Self.document)
        let first = try #require(codeViews(in: view).first)
        first.setContent("something else entirely\nover two lines", highlightMap: nil)

        RenderProbe.show(Self.document, in: view)

        #expect(codeViews(in: view).map(\.content) == codeSources(Self.document))
        let rebuilt = try #require(codeViews(in: view).first)
        #expect(reservedHeight(for: rebuilt, in: view.textLabelView.attributedText) == rebuilt.intrinsicContentSize.height)
    }

    @MainActor
    @Test("Two views sharing one provider never hand each other's views out")
    func sharedProviderKeepsViewsApart() {
        let provider = ReusableViewProvider()
        let left = MarkdownTextView(viewProvider: provider)
        let right = MarkdownTextView(viewProvider: provider)
        let leftDocument = "```swift\nlet left = 1\n```\n\n| L |\n| - |\n| l |"
        let rightDocument = "```swift\nlet right = 2\n```\n\n| R |\n| - |\n| r |"
        for _ in 0 ..< 3 {
            RenderProbe.show(leftDocument, in: left)
            RenderProbe.show(rightDocument, in: right)
        }
        let leftViews = Set(left.contextViews.map(ObjectIdentifier.init))
        let rightViews = Set(right.contextViews.map(ObjectIdentifier.init))
        #expect(leftViews.isDisjoint(with: rightViews))
        #expect(codeViews(in: left).map(\.content) == ["let left = 1"])
        #expect(codeViews(in: right).map(\.content) == ["let right = 2"])
        #expect(tableViews(in: left).first?.contents.map { $0.map(\.string) } == [["L"], ["l"]])
        #expect(tableViews(in: right).first?.contents.map { $0.map(\.string) } == [["R"], ["r"]])
    }

    // MARK: - Streaming

    @MainActor
    @Test("Streaming into the last code block shows the right code at every step")
    func streamedCodeStaysAccurate() throws {
        let final = """
        Some text.

        ```swift
        let settled = "unchanged while the next block streams"
        ```

        | K | V |
        | - | - |
        | a | 1 |

        ```swift
        func streamed() {
            print("arriving token by token")
        }
        ```

        Done.
        """
        let view = MarkdownTextView()
        let characters = Array(final)
        var settled: CodeView?
        for cursor in 1 ... characters.count {
            let prefix = String(characters[0 ..< cursor])
            RenderProbe.show(prefix, in: view)
            let codes = codeViews(in: view)
            #expect(codes.map(\.content) == codeSources(prefix), "at \(cursor)")
            #expect(placedCodeViews(in: view.textLabelView.attributedText).map(ObjectIdentifier.init)
                == codes.map(ObjectIdentifier.init), "at \(cursor)")
            #expect(Set(codes.map(ObjectIdentifier.init)).count == codes.count, "at \(cursor)")
            // Once the first block is closed its view stays put.
            if codes.count >= 2 {
                if let settled { #expect(codes[0] === settled, "at \(cursor)") }
                settled = codes[0]
            }
            for codeView in codes {
                #expect(
                    reservedHeight(for: codeView, in: view.textLabelView.attributedText)
                        == codeView.intrinsicContentSize.height,
                    "at \(cursor)"
                )
            }
        }
        RenderProbe.show(final, in: view)

        let oneShot = RenderProbe.view(final)
        RenderProbe.show(final, in: oneShot)
        let streamedDigest = RenderProbe.digest(view.textLabelView.attributedText)
        let oneShotDigest = RenderProbe.digest(oneShot.textLabelView.attributedText)
        #expect(streamedDigest == oneShotDigest, "\(RenderProbe.firstDifference(streamedDigest, oneShotDigest))")
        #expect(copiedText(view) == copiedText(oneShot))
        #expect(view.boundingSize(for: 480).height == oneShot.boundingSize(for: 480).height)
    }

    // MARK: - Value equality

    @MainActor
    @Test("Attachments compare equal exactly when everything they show matches")
    func attachmentEquality() {
        let theme = MarkdownTheme.default
        func make(
            _ language: String = "swift",
            _ content: String = "let a = 1",
            theme: MarkdownTheme = theme,
            size: CGSize = .init(width: 100, height: 40)
        ) -> ContextViewAttachment {
            .init(
                representation: .init(string: content + "\n"),
                appearance: .init(kind: .code(language: language, content: content), theme: theme, size: size)
            )
        }
        var otherTheme = theme
        otherTheme.fonts.code = .monospacedSystemFont(ofSize: 22, weight: .regular)

        #expect(make() == make())
        #expect(NSAttributedString(string: "x", attributes: [.litextAttachment: make()])
            .isEqual(to: NSAttributedString(string: "x", attributes: [.litextAttachment: make()])))
        #expect(make() != make("python"))
        #expect(make() != make("swift", "let a = 2"))
        #expect(make() != make(theme: otherTheme))
        #expect(make() != make(size: .init(width: 100, height: 41)))
        #expect(make() != make(size: .init(width: 101, height: 40)))

        let cells = [[NSAttributedString(string: "a")]]
        let table = ContextViewAttachment(
            representation: .init(string: "a\n"),
            appearance: .init(kind: .table(cells: cells, columnAlignments: [.left]), theme: theme, size: .init(width: 10, height: 10))
        )
        let realigned = ContextViewAttachment(
            representation: .init(string: "a\n"),
            appearance: .init(kind: .table(cells: cells, columnAlignments: [.right]), theme: theme, size: .init(width: 10, height: 10))
        )
        let edited = ContextViewAttachment(
            representation: .init(string: "b\n"),
            appearance: .init(
                kind: .table(cells: [[NSAttributedString(string: "b")]], columnAlignments: [.left]),
                theme: theme,
                size: .init(width: 10, height: 10)
            )
        )
        #expect(table != realigned)
        #expect(table != edited)
        #expect(table != make())
    }
}
