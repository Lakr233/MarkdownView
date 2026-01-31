//
//  ContentView.swift
//  Example
//
//  Created by 秋星桥 on 2026/02/01.
//

import MarkdownView
import SwiftUI

let document = """
# Welcome to MarkdownView

This is a **demo** of the `MarkdownView` SwiftUI component.

## Features

- Supports **bold** and *italic* text
- Inline `code` and code blocks
- [Links](https://example.com)
- Lists (bulleted, numbered, and task lists)

## Code Example

```swift
struct HelloWorld {
    func greet() {
        print("Hello, World!")
    }
}
```

## Math Support

Inline math: $E = mc^2$

## Task List

- [x] Create SwiftUI wrapper
- [x] Support themes
- [ ] Add more examples

## Table

| Feature | Status |
|---------|--------|
| Bold    | ✅     |
| Italic  | ✅     |
| Code    | ✅     |

> This is a blockquote.
> It can span multiple lines.

---

*Thank you for using MarkdownView!*
"""

struct ContentView: View {
    @State private var markdownText: String = document
    @State private var playing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                MarkdownView(markdownText)
                    .padding()
            }
            .background(.gray.opacity(0.1))
            .background(.background)
            .toolbar {
                Button {
                    markdownText = ""
                    var copy = document
                    playing = true
                    DispatchQueue.global().async {
                        while !copy.isEmpty {
                            usleep(1000)
                            DispatchQueue.main.sync {
                                let value = copy.removeFirst()
                                markdownText += String(value)
                            }
                        }
                        DispatchQueue.main.async {
                            playing = false
                        }
                    }
                } label: {
                    Image(systemName: "play")
                }
                .disabled(playing)
            }
            .navigationTitle("MarkdownView Demo")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    ContentView()
}
