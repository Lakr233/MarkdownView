//
//  ContentView.swift
//  Example
//
//  Created by 秋星桥 on 2026/02/01.
//

import MarkdownView
import SwiftUI

let document = """
This is a **demo** of the `MarkdownView` SwiftUI component. Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.

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

## Table

| Feature | Status | Comment |
|---------|--------|--------|
| Bold    | ✅     | N/A     |
| Italic  | ✅     | ---     |
| Code    | ✅     | 1145141919810     |

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
                    tik()
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

    func tik() {
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
    }
}

#Preview {
    ContentView()
}
