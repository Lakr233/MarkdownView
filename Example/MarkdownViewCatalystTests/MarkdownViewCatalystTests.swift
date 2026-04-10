import MarkdownParser
@testable import MarkdownView
import Testing

#if canImport(UIKit)
    import UIKit

    struct MarkdownViewCatalystTests {
        @MainActor
        @Test("Table cells are reused across reconfiguration")
        func tableCellsAreReusedAcrossReconfiguration() {
            let manager = TableViewCellManager()
            let container = UIView(frame: .init(x: 0, y: 0, width: 400, height: 400))

            manager.configureCells(
                for: [
                    [makeText("A"), makeText("B")],
                    [makeText("C"), makeText("D")],
                ],
                in: container,
                cellPadding: 10,
                maximumCellWidth: 180
            )

            let originalIdentifiers = manager.cells.map(ObjectIdentifier.init)

            manager.configureCells(
                for: [
                    [makeText("AA"), makeText("BB")],
                    [makeText("CC"), makeText("DD")],
                ],
                in: container,
                cellPadding: 10,
                maximumCellWidth: 180
            )

            #expect(manager.cells.count == 4)
            #expect(manager.cells.map(ObjectIdentifier.init) == originalIdentifiers)
        }

        @MainActor
        @Test("Code toolbar remains interactive")
        func codeToolbarRemainsInteractive() {
            let codeView = CodeView(frame: .init(x: 0, y: 0, width: 260, height: 160))
            codeView.theme = .default
            codeView.content = "let value = 1"
            codeView.layoutIfNeeded()

            #expect(codeView.interactionTarget(at: CGPoint(x: 240, y: 20)) != nil)
        }

        @MainActor
        @Test("Mixed CJK and RTL text gets stable CoreText language attributes")
        func mixedCJKAndRTLTextGetsStableCoreTextLanguageAttributes() {
            let context = MarkdownTextView.PreprocessedContent(
                blocks: [],
                rendered: [:],
                highlightMaps: [:],
                locale: Locale(identifier: "zh-Hans")
            )
            let rendered = MarkdownInlineNode
                .text("中文段落 日本語かな العربية")
                .render(theme: .default, context: context, viewProvider: .init())

            #expect(language(at: "中", in: rendered) == "zh-Hans")
            #expect(language(at: "日", in: rendered) == "ja")
            #expect(language(at: "か", in: rendered) == "ja")
            #expect(language(at: "ع", in: rendered) == "ar")
        }

        @MainActor
        @Test("Multilingual markdown preprocesses and renders")
        func multilingualMarkdownPreprocessesAndRenders() {
            let markdown = """
            # 多语言 Layout

            混合中文、日本語かな、한국어, العربية, Lingri Linga。

            | Name | Value |
            | --- | --- |
            | 中文列 | 日本語かな |
            | العربية | Lingri Linga |

            ```swift
            let locale = "中文と日本語かな"
            ```

            After table and code.
            """
            let parserResult = MarkdownParser().parse(markdown)
            let content = MarkdownTextView.PreprocessedContent(
                parserResult: parserResult,
                theme: .default,
                locale: Locale(identifier: "zh-Hans")
            )
            let view = MarkdownTextView()

            view.setMarkdownManually(content)
            let size = view.boundingSize(for: 320)

            #expect(content.blocks.count >= 4)
            #expect(content.blocks.contains { if case .table = $0 { true } else { false } })
            #expect(content.blocks.contains { if case .codeBlock = $0 { true } else { false } })
            #expect(view.contextViews.contains { $0 is TableView })
            #expect(view.contextViews.contains { $0 is CodeView })
            #expect(size.width > 0)
            #expect(size.height > 0)
        }

        @MainActor
        @Test("MarkdownTextView reuses table and code context views")
        func markdownTextViewReusesContextViews() throws {
            let view = MarkdownTextView()

            view.setMarkdownManually(preprocessedContent(for: """
            | Name | Value |
            | --- | --- |
            | Alpha | One |

            ```swift
            let value = 1
            ```
            """))
            let originalTable = try #require(view.contextViews.first { $0 is TableView } as? TableView)
            let originalCode = try #require(view.contextViews.first { $0 is CodeView } as? CodeView)

            view.setMarkdownManually(preprocessedContent(for: """
            | Name | Value |
            | --- | --- |
            | Beta | Two |

            ```swift
            let value = 2
            ```
            """))
            let updatedTable = try #require(view.contextViews.first { $0 is TableView } as? TableView)
            let updatedCode = try #require(view.contextViews.first { $0 is CodeView } as? CodeView)

            #expect(originalTable === updatedTable)
            #expect(originalCode === updatedCode)
        }

        @MainActor
        @Test("MarkdownTextView keeps root text hittable through plain table and code")
        func markdownTextViewKeepsRootTextHittable() throws {
            let view = MarkdownTextView()
            view.frame = .init(x: 0, y: 0, width: 320, height: 480)
            view.setMarkdownManually(preprocessedContent(for: """
            Before

            | Name | Value |
            | --- | --- |
            | Alpha | Beta |

            ```swift
            let value = 1
            ```

            After
            """))

            let tableView = try #require(view.contextViews.first { $0 is TableView } as? TableView)
            let codeView = try #require(view.contextViews.first { $0 is CodeView } as? CodeView)

            let tableProbe = CGPoint(x: tableView.frame.midX, y: tableView.frame.midY)
            let codeProbe = CGPoint(x: codeView.frame.midX, y: codeView.frame.midY)

            let tableOverlayTarget = tableView.interactionTarget(at: tableView.convert(tableProbe, from: view))
            let codeOverlayTarget = codeView.interactionTarget(at: codeView.convert(codeProbe, from: view))
            let tableRootTarget = view.textView.hitTest(view.textView.convert(tableProbe, from: view), with: nil)
            let codeRootTarget = view.textView.hitTest(view.textView.convert(codeProbe, from: view), with: nil)

            #expect(tableOverlayTarget == nil)
            #expect(codeOverlayTarget == nil)
            #expect(tableRootTarget != nil)
            #expect(codeRootTarget != nil)
        }
    }

    @MainActor
    private func makeText(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: MarkdownTheme.default.fonts.body,
            ]
        )
    }

    @MainActor
    private func preprocessedContent(for markdown: String) -> MarkdownTextView.PreprocessedContent {
        MarkdownTextView.PreprocessedContent(
            parserResult: MarkdownParser().parse(markdown),
            theme: .default
        )
    }

    private func language(at needle: String, in attributedString: NSAttributedString) -> String? {
        let range = (attributedString.string as NSString).range(of: needle)
        guard range.location != NSNotFound else { return nil }
        return attributedString.attribute(.coreTextLanguage, at: range.location, effectiveRange: nil) as? String
    }
#endif
