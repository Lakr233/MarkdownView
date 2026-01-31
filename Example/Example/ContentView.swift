//
//  ContentView.swift
//  Example
//
//  Created by 秋星桥 on 2026/02/01.
//

import MarkdownView
import SwiftUI

struct ContentView: View {
    @State private var markdownText: String = """
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

    var body: some View {
        NavigationStack {
            ScrollView {
                MarkdownView(markdownText)
                    .padding()
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
