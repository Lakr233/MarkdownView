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
                metrics: testTableMetrics(maximumTextWidth: 180)
            )

            let originalIdentifiers = manager.cells.map(ObjectIdentifier.init)

            manager.configureCells(
                for: [
                    [makeText("AA"), makeText("BB")],
                    [makeText("CC"), makeText("DD")],
                ],
                in: container,
                metrics: testTableMetrics(maximumTextWidth: 180)
            )

            #expect(manager.cells.count == 4)
            #expect(manager.cells.map(ObjectIdentifier.init) == originalIdentifiers)
        }

        @MainActor
        @Test("Native table widths fill short tables and scroll wide tables")
        func nativeTableWidthsFillAndScroll() throws {
            for columnCount in [1, 2, 3, 5] {
                let tableView = TableView(frame: .init(x: 0, y: 0, width: 320, height: 120))
                let row = (0 ..< columnCount).map { makeText("C\($0)") }
                tableView.setContents([row, row])
                tableView.layoutIfNeeded()

                let scrollView = try #require(
                    tableView.subviews.first { $0 is UIScrollView } as? UIScrollView
                )
                let gridView = try #require(
                    scrollView.subviews.first { $0 is GridView } as? GridView
                )
                if columnCount <= 3 {
                    #expect(abs(gridView.frame.width - tableView.bounds.width) <= 0.5)
                } else {
                    #expect(gridView.frame.width > tableView.bounds.width)
                }
            }
        }

        @MainActor
        @Test("Markdown table alignment reaches UIKit cells")
        func markdownTableAlignmentReachesUIKitCells() throws {
            let view = MarkdownTextView()
            view.frame = .init(x: 0, y: 0, width: 390, height: 240)
            view.setContentImmediately(preprocessedContent(for: """
            | Left | Center | Right |
            | :--- | :---: | ---: |
            | A | B | C |
            """))

            let tableView = try #require(view.contextViews.first as? TableView)
            let scrollView = try #require(
                tableView.subviews.first { $0 is UIScrollView } as? UIScrollView
            )
            let cells = scrollView.subviews.compactMap { $0 as? TextLabelView }

            #expect(tableView.columnAlignments == [.left, .center, .right])
            #expect(cells.count == 6)
            #expect(paragraphAlignment(in: cells[0]) == .left)
            #expect(paragraphAlignment(in: cells[1]) == .center)
            #expect(paragraphAlignment(in: cells[2]) == .right)
        }

        @MainActor
        @Test("Default table appearance reaches rendered UIKit layers")
        func defaultTableAppearanceReachesRenderedLayers() throws {
            let tableView = TableView(frame: .init(x: 0, y: 0, width: 320, height: 180))
            tableView.setTheme(.default)
            tableView.setContents([
                [makeText("Feature"), makeText("Status")],
                [makeText("Bold"), makeText("Done")],
                [makeText("Italic"), makeText("Done")],
            ])
            tableView.layoutIfNeeded()

            let scrollView = try #require(
                tableView.subviews.first { $0 is UIScrollView } as? UIScrollView
            )
            let gridView = try #require(
                scrollView.subviews.first { $0 is GridView } as? GridView
            )
            gridView.layoutIfNeeded()

            let layers = try #require(gridView.layer.sublayers)
            let backgroundLayer = try #require(layers[0] as? CAShapeLayer)
            let stripeLayer = try #require(layers[1] as? CAShapeLayer)
            let headerLayer = try #require(layers[2] as? CAShapeLayer)
            let borderLayer = try #require(layers[3] as? CAShapeLayer)
            let backgroundColor = try #require(backgroundLayer.fillColor)
            let stripeColor = try #require(stripeLayer.fillColor)
            let headerColor = try #require(headerLayer.fillColor)
            let stripePath = try #require(stripeLayer.path)
            let borderPath = try #require(borderLayer.path)

            #expect(UIColor(cgColor: backgroundColor).isEqual(UIColor.clear))
            #expect(colorsMatch(
                rendered: stripeColor,
                expected: MarkdownTheme.default.table.stripeCellBackgroundColor,
                traitCollection: gridView.traitCollection
            ))
            #expect(colorsMatch(
                rendered: headerColor,
                expected: MarkdownTheme.default.table.headerBackgroundColor,
                traitCollection: gridView.traitCollection
            ))
            #expect(!stripePath.isEmpty)
            #expect(borderPath.boundingBox.width > 0)
            #expect(pathContainsCurve(borderPath))
            #expect(MarkdownTheme.default.table.cornerRadius == 8)
        }

        @MainActor
        @Test("UIKit table cells are vertically centered within each row")
        func tableCellsAreVerticallyCentered() throws {
            let tableView = TableView(frame: .init(x: 0, y: 0, width: 320, height: 120))
            tableView.setContents([
                [makeText("Short"), makeText("First line\nSecond line")],
            ])
            tableView.layoutIfNeeded()

            let scrollView = try #require(
                tableView.subviews.first { $0 is UIScrollView } as? UIScrollView
            )
            let cells = scrollView.subviews.compactMap { $0 as? TextLabelView }

            #expect(cells.count == 2)
            #expect(abs(cells[0].frame.midY - cells[1].frame.midY) <= 0.5)
            #expect(cells[0].frame.minY > cells[1].frame.minY)
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
            let context = MarkdownContent(
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
            let content = MarkdownContent(
                parserResult: parserResult,
                theme: .default,
                locale: Locale(identifier: "zh-Hans")
            )
            let view = MarkdownTextView()

            view.setContentImmediately(content)
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

            view.setContentImmediately(preprocessedContent(for: """
            | Name | Value |
            | --- | --- |
            | Alpha | One |

            ```swift
            let value = 1
            ```
            """))
            let originalTable = try #require(view.contextViews.first { $0 is TableView } as? TableView)
            let originalCode = try #require(view.contextViews.first { $0 is CodeView } as? CodeView)

            view.setContentImmediately(preprocessedContent(for: """
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
            view.setContentImmediately(preprocessedContent(for: """
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
            let tableRootTarget = view.textLabelView.hitTest(view.textLabelView.convert(tableProbe, from: view), with: nil)
            let codeRootTarget = view.textLabelView.hitTest(view.textLabelView.convert(codeProbe, from: view), with: nil)

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

    private func testTableMetrics(maximumTextWidth: CGFloat) -> TableLayoutMetrics {
        TableLayoutMetrics(
            minimumColumnWidth: 20,
            maximumColumnWidth: maximumTextWidth + 20,
            horizontalCellPadding: 10,
            verticalCellPadding: 10,
            minimumRowHeight: 0
        )
    }

    @MainActor
    private func paragraphAlignment(in cell: TextLabelView) -> NSTextAlignment? {
        guard cell.attributedText.length > 0 else { return nil }
        return (cell.attributedText.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle)?.alignment
    }

    private func pathContainsCurve(_ path: CGPath) -> Bool {
        var containsCurve = false
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .addCurveToPoint, .addQuadCurveToPoint:
                containsCurve = true
            default:
                break
            }
        }
        return containsCurve
    }

    private func colorsMatch(
        rendered: CGColor,
        expected: UIColor,
        traitCollection: UITraitCollection
    ) -> Bool {
        let renderedColor = UIColor(cgColor: rendered)
        let resolvedExpected = expected.resolvedColor(with: traitCollection)
        var renderedRed: CGFloat = 0
        var renderedGreen: CGFloat = 0
        var renderedBlue: CGFloat = 0
        var renderedAlpha: CGFloat = 0
        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0
        guard renderedColor.getRed(
            &renderedRed,
            green: &renderedGreen,
            blue: &renderedBlue,
            alpha: &renderedAlpha
        ), resolvedExpected.getRed(
            &expectedRed,
            green: &expectedGreen,
            blue: &expectedBlue,
            alpha: &expectedAlpha
        ) else { return false }

        return abs(renderedRed - expectedRed) <= 0.001
            && abs(renderedGreen - expectedGreen) <= 0.001
            && abs(renderedBlue - expectedBlue) <= 0.001
            && abs(renderedAlpha - expectedAlpha) <= 0.001
    }

    @MainActor
    private func preprocessedContent(for markdown: String) -> MarkdownContent {
        MarkdownContent(
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
