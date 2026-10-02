//
//  CatalogView.swift
//  MarkdownViewCatalog
//

#if os(macOS)
    import MarkdownView
    import SwiftUI

    struct CatalogView: View {
        @State private var selection: CatalogSample.ID? = CatalogSample.chatAnswer.id
        @State private var theme: MarkdownTheme = .default
        @State private var appearance: CatalogAppearance = .sideBySide
        @State private var width: CatalogWidth = .reading
        @State private var showsSource = false
        @State private var editingTheme = false

        var body: some View {
            NavigationSplitView {
                List(selection: $selection) {
                    ForEach(CatalogSample.groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.samples) { sample in
                                Label {
                                    Text(sample.title)
                                } icon: {
                                    // One column for every symbol, whatever its natural width.
                                    Image(systemName: sample.systemImage)
                                        .frame(width: 20)
                                }
                                .tag(sample.id)
                            }
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            } detail: {
                if let sample = CatalogSample.all.first(where: { $0.id == selection }) {
                    CatalogPage(
                        sample: sample,
                        theme: theme,
                        appearance: appearance,
                        width: width,
                        showsSource: showsSource,
                    )
                    .id(sample.id)
                } else {
                    Text("Select a component")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Picker("Appearance", selection: Binding(
                        get: { appearance },
                        set: { newValue in
                            appearance = newValue
                            // Light and Dark restyle the whole app, sidebar and
                            // toolbar included, not only the rendered page.
                            NSApplication.shared.appearance = newValue.applicationAppearance
                        },
                    )) {
                        ForEach(CatalogAppearance.allCases) { appearance in
                            Label(appearance.title, systemImage: appearance.systemImage)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("Appearance")

                    Picker("Width", selection: $width) {
                        ForEach(CatalogWidth.allCases) { width in
                            Text(width.title).tag(width)
                        }
                    }
                    .help("Content width")

                    Toggle(isOn: $showsSource) {
                        Label("Source", systemImage: "doc.plaintext")
                    }
                    .help("Show and edit the markdown source")

                    Button {
                        editingTheme = true
                    } label: {
                        Label("Theme", systemImage: "paintpalette")
                    }
                    .help("Edit the theme")
                    .popover(isPresented: $editingTheme) {
                        ThemeEditor(theme: $theme)
                            .frame(width: 380, height: 640)
                    }
                }
            }
            .task {
                await CatalogSnapshot.run { selection = $0 }
            }
            .task {
                await CatalogResizeStress.run { selection = $0 } fill: { width = .fill }
            }
        }
    }

    /// The detail column: one sample rendered on a canvas, optionally beside
    /// its editable source.
    private struct CatalogPage: View {
        let sample: CatalogSample
        let theme: MarkdownTheme
        let appearance: CatalogAppearance
        let width: CatalogWidth
        let showsSource: Bool

        @State private var source: String
        @State private var streaming: Task<Void, Never>?

        init(
            sample: CatalogSample,
            theme: MarkdownTheme,
            appearance: CatalogAppearance,
            width: CatalogWidth,
            showsSource: Bool,
        ) {
            self.sample = sample
            self.theme = theme
            self.appearance = appearance
            self.width = width
            self.showsSource = showsSource
            _source = State(initialValue: sample.markdown)
        }

        var body: some View {
            GeometryReader { proxy in
                // The source takes one share and each rendered pane another,
                // so source, light and dark all get the same width.
                let shares = CGFloat(appearance.schemes.count + (showsSource ? 1 : 0))
                let paneWidth = proxy.size.width / shares
                HStack(spacing: 0) {
                    if showsSource {
                        TextEditor(text: $source)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .sourceMargins()
                            .frame(width: paneWidth)
                            .background(.background)
                        Divider()
                    }
                    canvas
                }
            }
            .navigationTitle(sample.title)
            .navigationSubtitle(sample.summary)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        stream()
                    } label: {
                        Label("Stream", systemImage: streaming == nil ? "play" : "stop")
                    }
                    .help("Replay the source as a streamed answer")

                    Button {
                        streaming?.cancel()
                        source = sample.markdown
                    } label: {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                    }
                    .help("Restore the original source")
                    .disabled(source == sample.markdown && streaming == nil)
                }
            }
            .onDisappear {
                streaming?.cancel()
            }
        }

        /// Panes share one scroll view, so light and dark stay on the same
        /// rows: the same source at the same width lays out to the same height.
        private var canvas: some View {
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(appearance.schemes, id: \.self) { scheme in
                        MarkdownView(source, theme: theme)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 28)
                            .frame(maxWidth: width.points)
                            .frame(maxWidth: .infinity)
                            .modifier(ColorSchemeOverride(scheme: scheme))
                        if scheme != appearance.schemes.last {
                            // Keeps the panes over their backgrounds below.
                            Divider().hidden()
                        }
                    }
                }
            }
            .background {
                // Behind the scroll view, so each pane's color fills the
                // viewport even when the document is shorter than it.
                HStack(spacing: 0) {
                    ForEach(appearance.schemes, id: \.self) { scheme in
                        Color(nsColor: .textBackgroundColor)
                            .modifier(ColorSchemeOverride(scheme: scheme))
                        if scheme != appearance.schemes.last {
                            Divider()
                        }
                    }
                }
            }
        }

        private func stream() {
            if let streaming {
                streaming.cancel()
                return
            }
            let document = sample.markdown
            source = ""
            streaming = Task {
                var remaining = Substring(document)
                while !remaining.isEmpty, !Task.isCancelled {
                    // Token-sized chunks, at roughly the pace a model emits them.
                    let chunk = remaining.prefix(Int.random(in: 2 ... 6))
                    remaining = remaining.dropFirst(chunk.count)
                    source += chunk
                    try? await Task.sleep(for: .milliseconds(12))
                }
                streaming = nil
            }
        }
    }

    private extension View {
        /// Insets the source inside its scroll view, so lines scroll to the
        /// pane's edge rather than being cut off a margin short of it.
        @ViewBuilder
        func sourceMargins() -> some View {
            if #available(macOS 14, *) {
                contentMargins(.horizontal, 20, for: .scrollContent)
                    .contentMargins(.vertical, 24, for: .scrollContent)
            } else {
                padding(8)
            }
        }
    }

    /// Pins a pane to light or dark, or leaves it on the system setting.
    private struct ColorSchemeOverride: ViewModifier {
        let scheme: ColorScheme?
        @Environment(\.colorScheme) private var systemScheme

        func body(content: Content) -> some View {
            content.environment(\.colorScheme, scheme ?? systemScheme)
        }
    }

    enum CatalogAppearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark
        case sideBySide

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            case .sideBySide: "Light and Dark"
            }
        }

        var systemImage: String {
            switch self {
            case .system: "circle.lefthalf.filled"
            case .light: "sun.max"
            case .dark: "moon"
            case .sideBySide: "rectangle.split.2x1"
            }
        }

        /// The appearance the whole app takes; `nil` follows the system.
        var applicationAppearance: NSAppearance? {
            switch self {
            case .system, .sideBySide: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        }

        /// The schemes to render, one pane each; `nil` follows the app.
        var schemes: [ColorScheme?] {
            switch self {
            case .system, .light, .dark: [nil]
            case .sideBySide: [.light, .dark]
            }
        }
    }

    enum CatalogWidth: String, CaseIterable, Identifiable {
        case phone
        case reading
        case wide
        case fill

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .phone: "Phone · 390"
            case .reading: "Reading · 720"
            case .wide: "Wide · 1000"
            case .fill: "Fill"
            }
        }

        var points: CGFloat {
            switch self {
            case .phone: 390
            case .reading: 720
            case .wide: 1000
            case .fill: .infinity
            }
        }
    }
#endif
