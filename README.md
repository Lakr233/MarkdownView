# MarkdownView

A pure UIKit/AppKit framework for rendering Markdown with real-time parsing and rendering. Battle tested in [FlowDown](https://github.com/Lakr233/FlowDown).

> [!IMPORTANT]
> MarkdownView is **not a full-spec CommonMark renderer**. It deliberately trades spec completeness for the best possible typography and layout on phone-sized screens: complex elements (tables, code blocks) are lifted out of lists and rendered as first-class blocks, line spacing and fonts follow platform text styles, and rendering stays smooth while streaming tokens from an LLM. If you need byte-exact CommonMark output, use a spec-focused renderer instead.

## Preview

![Preview](./Resources/Simulator%20Screenshot%20-%20iPad%20mini%20(A17%20Pro)%20-%202025-05-27%20at%2003.03.27.png)

## Features

- 🚀 **Real-time Rendering**: designed for streaming — updates are throttled and views are reused, so calling it on every token is fine
- 📱 **Mobile-first Layout**: complex elements are extracted from lists and laid out for readability on small screens
- 🎨 **Syntax Highlighting**: code blocks highlighted asynchronously with Highlightr
- 📊 **Math Rendering**: LaTeX formulas rendered with SwiftMath, with tap-to-preview
- 🖥️ **Cross-Platform**: native iOS, macOS, Mac Catalyst, visionOS, and watchOS (via `WatchMarkdownView`)

## Supported Markdown

GitHub-flavored basics: headings, paragraphs, emphasis, lists (ordered/unordered/task), blockquotes, fenced code blocks, tables, links, images-as-links, inline and block math (`$...$`, `$$...$$`). HTML blocks and other long-tail CommonMark constructs are rendered as plain text or simplified — by design.

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Lakr233/MarkdownView", from: "4.0.0"),
]
```

Platform compatibility:
- iOS 16.0+
- macOS 13.0+
- Mac Catalyst 16.0+
- visionOS 1.0+
- watchOS 8.0+ (`WatchMarkdownView` product)

## Usage

### SwiftUI

```swift
import MarkdownView

struct ContentView: View {
    var body: some View {
        MarkdownView("# Hello World")
    }
}
```

With custom theme:

```swift
MarkdownView("# Hello World", theme: .default)
```

### UIKit / AppKit

One-shot rendering:

```swift
import MarkdownView

let markdownTextView = MarkdownTextView()
markdownTextView.setMarkdown("# Hello World")
```

Streaming (parse off the main path you control, display throttled):

```swift
import MarkdownView
import MarkdownParser

let markdownTextView = MarkdownTextView()

// on every incoming chunk:
let result = MarkdownParser().parse(accumulatedText)
let content = MarkdownContent(parserResult: result, theme: .default)
markdownTextView.setContent(content) // coalesced by throttleInterval (default 20 fps)
```

Immediate, unthrottled replacement:

```swift
markdownTextView.setContentImmediately(content)
```

### watchOS

```swift
import WatchMarkdownView

WatchMarkdownView(markdown: "# Hello World")
```

## Migrating to 4.0

MarkdownView 4.0 adopts Litext 2.0 and renames the core API. Deprecated shims are provided for one release:

| 3.x | 4.0 |
| --- | --- |
| `MarkdownTextView.PreprocessedContent` | `MarkdownContent` |
| `setMarkdown(_: PreprocessedContent)` | `setContent(_:)` |
| `setMarkdownManually(_:)` | `setContentImmediately(_:)` |
| `bindContentOffset(from:)` | `trackedScrollView = ...` |
| `markdownTextView.textView` | `markdownTextView.textLabelView` |
| `ParseResult.render(theme:)` (two overloads) | `renderedContent(theme:)` / `highlightMaps(theme:)` |

New: `setMarkdown(_ text: String)` parses and displays a markdown string in one call; `MarkdownContent(markdown:theme:locale:)` does the same for content objects.

## Example

Check out the included example project to see MarkdownView in action:

```bash
open Example.xcworkspace
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

### Acknowledgments

This project includes code adapted from [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) by Guillermo Gonzalez, used under the MIT License.

## Sponsor

[LookInside](https://lookinside-app.com/) helps you inspect a running iOS or macOS app UI from your Mac.

---

Copyright 2025 © Lakr Aream. All rights reserved.
