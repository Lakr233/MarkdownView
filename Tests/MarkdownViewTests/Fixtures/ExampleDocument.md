# MarkdownView

This is a **demo** of the `MarkdownView` SwiftUI component. Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.

## Inline Styles

- Supports **bold**, *italic*, ***bold italic***, ~~strikethrough~~ and `inline code`
- [Links](https://example.com), autolinks like <https://example.com>, and [reference links][ref]
- Escapes: \*not italic\*, entities: &copy; &amp; &rarr;
- A very long unbreakable token that stresses narrow layouts: `supercalifragilisticexpialidocious_token_1145141919810`
- Emoji and CJK: 🎉 中文排版、日本語のかな、한국어 混排

[ref]: https://example.com

## Headings

### Level Three Heading

#### Level Four Heading With A Fairly Long Title That Wraps When Narrow

##### Level Five

## Lists

1. First ordered item
2. Second ordered item
   1. Nested ordered item
   2. Another nested item
3. Third ordered item

- Bulleted item
  - Nested bullet with a long sentence so it wraps on narrow widths
    - Third level bullet
- [ ] Unchecked task
- [x] Checked task

## Code Example

```swift
struct HelloWorld {
    func greet() {
        print("Hello, World!")
    }
}
```

A code block with long lines that must scroll horizontally instead of wrapping:

```python
def compute(values: list[int]) -> int:
    return sum(value * 2 for value in values if value % 2 == 0 and value > 0 and value < 1000)
```

```
plain fenced block without a language
```

## Math Support

Inline math: $E = mc^2$, and another one $\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$.

Display math:

$$
\int_{0}^{\infty} e^{-x^2} \, dx = \frac{\sqrt{\pi}}{2}
$$

## Tables

| Feature | Status | Comment |
|---------|--------|--------|
| Bold    | ✅     | N/A     |
| Italic  | ✅     | ---     |
| Code    | ✅     | 1145141919810     |

Alignment and wrapping:

| Left aligned | Centered | Right aligned |
| :----------- | :------: | ------------: |
| short | mid | 1 |
| a considerably longer cell that has to wrap | **bold** and `code` | 1145141919810 |
| 中文单元格内容 | [link](https://example.com) | -42 |

A long table shows its first eight rows; tap the last row or the expand button to see all of them and sort by a column:

| Rank | Language | Stars | Notes |
| ---: | :------- | ----: | :---- |
| 1 | Swift | 67,800 | `async`/`await` |
| 2 | Rust | 98,100 | [rust-lang.org](https://www.rust-lang.org) |
| 3 | Go | 123,000 | 中文社区活跃 |
| 4 | Kotlin | 49,300 | |
| 5 | TypeScript | 101,000 | **typed** JavaScript |
| 6 | Zig | 35,200 | `comptime` |
| 7 | Python | 63,400 | 日本語のドキュメント |
| 8 | C | 9,800 | |
| 9 | Haskell | 3,000 | *lazy* |
| 10 | Elixir | 24,100 | BEAM |
| 11 | Dart | 10,300 | Flutter |
| 12 | Julia | 45,600 | 科学计算 |

## Blockquotes

> This is a blockquote.
> It can span multiple lines.

> A blockquote with **inline styles**, `code`, and a [link](https://example.com)
> plus a second paragraph that keeps wrapping when the window gets narrow.

## Thematic Breaks

---

*Thank you for using MarkdownView!*