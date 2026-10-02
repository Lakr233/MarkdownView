//
//  ThemeEditor.swift
//  Example
//
//  Created by 秋星桥 on 2026/10/02.
//

import MarkdownView
import SwiftUI

/// Edits every token of a ``MarkdownTheme`` live, for debugging the renderer.
///
/// A picked colour is a single static colour, so it no longer follows the
/// light and dark appearance the default it replaces did. Reset restores the
/// dynamic defaults.
struct ThemeEditor: View {
    @Binding var theme: MarkdownTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                fontsSection
                colorsSection
                spacingsSection
                tableSection
                syntaxSection
            }
            .formStyle(.grouped)
            .navigationTitle("Theme")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Reset") {
                            theme = .default
                        }
                        .disabled(theme == .default)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }

    private var fontsSection: some View {
        Section("Fonts") {
            ValueSlider(
                title: "Body (aligns all)",
                value: Binding(
                    get: { theme.fonts.body.pointSize },
                    set: { theme.align(to: $0) },
                ),
                range: 8 ... 32,
            )
            ValueSlider(title: "Code", value: fontSize(\.fonts.code), range: 6 ... 32)
            ValueSlider(title: "Inline Code", value: fontSize(\.fonts.codeInline), range: 6 ... 32)
            ValueSlider(title: "Title", value: fontSize(\.fonts.title), range: 8 ... 48)
            ValueSlider(title: "Large Title", value: fontSize(\.fonts.largeTitle), range: 8 ... 48)
            ValueSlider(title: "Footnote", value: fontSize(\.fonts.footnote), range: 6 ... 32)
        }
    }

    private var colorsSection: some View {
        Section("Colors") {
            ColorPicker("Body", selection: color(\.colors.body))
            ColorPicker("Highlight", selection: color(\.colors.highlight))
            ColorPicker("Emphasis", selection: color(\.colors.emphasis))
            ColorPicker("Inline Code", selection: color(\.colors.code))
            ColorPicker("Inline Code Background", selection: color(\.colors.codeBackground))
            ColorPicker("Code Block Background", selection: color(\.colors.codeBlockBackground))
            ColorPicker("Code Block Bar", selection: color(\.colors.codeBlockBarBackground))
            ColorPicker(
                "Selection",
                selection: Binding(
                    get: { Color(platformColor: theme.colors.selectionBackground ?? .clear) },
                    set: { theme.colors.selectionBackground = PlatformColor($0) },
                ),
            )
        }
    }

    private var spacingsSection: some View {
        Section("Spacings") {
            ValueSlider(title: "Paragraph", value: $theme.spacings.paragraph, range: 0 ... 48)
            ValueSlider(title: "Before Heading", value: $theme.spacings.headingBefore, range: 0 ... 48)
            ValueSlider(title: "General", value: $theme.spacings.general, range: 0 ... 48)
            ValueSlider(title: "List", value: $theme.spacings.list, range: 0 ... 48)
            ValueSlider(title: "Cell", value: $theme.spacings.cell, range: 0 ... 64)
            ValueSlider(title: "Final", value: $theme.spacings.final, range: 0 ... 48)
            ValueSlider(title: "Bullet Size", value: $theme.sizes.bullet, range: 1 ... 12)
        }
    }

    private var tableSection: some View {
        Section("Table") {
            ValueSlider(title: "Corner Radius", value: $theme.table.cornerRadius, range: 0 ... 24)
            ValueSlider(title: "Border Width", value: $theme.table.borderWidth, range: 0 ... 4, step: 0.5)
            ColorPicker("Border", selection: color(\.table.borderColor))
            ColorPicker("Header Background", selection: color(\.table.headerBackgroundColor))
            ColorPicker("Cell Background", selection: color(\.table.cellBackgroundColor))
            ColorPicker("Stripe Background", selection: color(\.table.stripeCellBackgroundColor))
        }
    }

    private var syntaxSection: some View {
        Section("Syntax") {
            ColorPicker("Comment", selection: color(\.syntax.comment))
            ColorPicker("Keyword", selection: color(\.syntax.keyword))
            ColorPicker("String", selection: color(\.syntax.string))
            ColorPicker("Number", selection: color(\.syntax.number))
            ColorPicker("Type", selection: color(\.syntax.type))
            ColorPicker("Attribute", selection: color(\.syntax.attribute))
            ColorPicker("Meta", selection: color(\.syntax.meta))
            ColorPicker("Variable", selection: color(\.syntax.variable))
        }
    }

    private func color(_ keyPath: WritableKeyPath<MarkdownTheme, PlatformColor>) -> Binding<Color> {
        Binding(
            get: { Color(platformColor: theme[keyPath: keyPath]) },
            set: { theme[keyPath: keyPath] = PlatformColor($0) },
        )
    }

    private func fontSize(_ keyPath: WritableKeyPath<MarkdownTheme, PlatformFont>) -> Binding<CGFloat> {
        Binding(
            get: { theme[keyPath: keyPath].pointSize },
            set: { theme[keyPath: keyPath] = theme[keyPath: keyPath].withSize($0) },
        )
    }
}

private struct ValueSlider: View {
    let title: LocalizedStringKey
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var step: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .number.precision(.fractionLength(0 ... 1)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

private extension Color {
    init(platformColor: PlatformColor) {
        #if canImport(UIKit)
            self.init(uiColor: platformColor)
        #else
            self.init(nsColor: platformColor)
        #endif
    }
}
