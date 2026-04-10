# 多语言レンダリング Stress

中文段落保持稳定。日本語かな交じりの文も同じ段落で扱う。English words stay selectable. العربية داخل الفقرة.

| 语言 | 内容 |
| --- | --- |
| zh-Hans | 中文单元格<br>第二行 |
| ja | 日本語かなと漢字 |
| mixed | ChatGPT 回复: 这是中文 / これは日本語かな / مرحبا |

```swift
let message = "中文 日本語かな العربية"
print(message)
```

- 第一项 with English
- 第二項目かな
- بند عربي
